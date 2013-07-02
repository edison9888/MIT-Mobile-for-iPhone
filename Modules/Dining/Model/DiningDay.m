#import "DiningDay.h"
#import "HouseVenue.h"
#import "DiningMeal.h"
#import "CoreDataManager.h"
#import "Foundation+MITAdditions.h"

@implementation DiningDay

@dynamic date;
@dynamic message;
@dynamic meals;
@dynamic houseVenue;

+ (DiningDay *)newDayWithDictionary:(NSDictionary *)dict {
    DiningDay *day = [CoreDataManager insertNewObjectForEntityForName:@"DiningDay"];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd"];
    NSDate *date = [formatter dateFromString:dict[@"date"]];
    day.date = date;
    
    if (dict[@"message"]) {
        day.message = dict[@"message"];
    }
    
    for (NSDictionary *mealDict in dict[@"meals"]) {
        DiningMeal *meal = [DiningMeal newMealWithDictionary:mealDict];
        if (meal) {
            [day addMealsObject:meal];
            
            // adjust all of the start and end times to be complete dates and times to make querying easier
            
            if (meal.startTime && meal.endTime) {
                NSDate *dayDate = day.date;
                
                meal.startTime = [dayDate dateWithTimeOfDayFromDate:meal.startTime];
                
                meal.endTime = [dayDate dateWithTimeOfDayFromDate:meal.endTime];
            }
        }
    }
    
    if ([day.meals count] > 0) {
        NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"startTime" ascending:YES];
        NSArray *sortedMeals = [[day.meals array] sortedArrayUsingDescriptors:@[sort]];
        [day setMeals:[NSOrderedSet orderedSetWithArray:sortedMeals]];
    }
    
    return day;
}

+ (DiningDay *)dayForDate:(NSDate *) date forVenue:(HouseVenue *)venue
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"date == %@ && houseVenue == %@", date, venue];
    NSArray * array = [CoreDataManager objectsForEntity:@"DiningDay" matchingPredicate:predicate];
    
    return [array lastObject];
}

+ (NSArray *)daysInWeekOfDate:(NSDate *)date forVenue:(HouseVenue *)venue
{
    // returns array of DiningDays with weekday component 1 thru 7 of date
    //      sorted ascending by date
    NSDate *weekStart = nil;
    NSTimeInterval duration = 0;
    [[NSCalendar cachedCurrentCalendar] setFirstWeekday:1];
    [[NSCalendar cachedCurrentCalendar] rangeOfUnit:NSWeekCalendarUnit startDate:&weekStart interval:&duration forDate:date];
    NSDate *weekEnd = [weekStart dateByAddingTimeInterval:duration];
    
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"houseVenue == %@ AND date >= %@ AND date <= %@", venue, [weekStart startOfDay], [weekEnd endOfDay]];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES];
    
    return [CoreDataManager objectsForEntity:@"DiningDay" matchingPredicate:pred sortDescriptors:@[sort]];
}

// There appears to be a bug in Apple's autogenerated NSOrderedSet accessors: http://stackoverflow.com/questions/7385439/exception-thrown-in-nsorderedset-generated-accessors
- (void)addMealsObject:(DiningMeal *)value {
    NSMutableOrderedSet* tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.meals];
    [tempSet addObject:value];
    self.meals = tempSet;
}

/** Return all of hours for today as a comma-delimited list, e.g. "9am - 5pm, 5:30pm - 8:00pm". If the day has a message, all of the hours for the day are ignored and that message is displayed. Just because this returns a message shouldn't be taken to mean the venue is closed for the day.
 */

- (NSString *)allHoursSummary {
    if (self.message) {
        return self.message;
    }
    NSMutableArray *summaries = [NSMutableArray array];
    for (DiningMeal *meal in self.meals) {
        NSString *summary = [meal hoursSummary];
        if (summary) {
            [summaries addObject:summary];
        }
    }
    if ([summaries count] > 0) {
        return [summaries componentsJoinedByString:@", "];
    }
    else {
        return @"Closed for the day";
    }
}

- (DiningMeal *)mealWithName:(NSString *)name
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name ==[c] %@", name];
    return [[[self.meals set] filteredSetUsingPredicate:predicate] anyObject];
}

- (DiningMeal *)mealForDate:(NSDate *)date {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"startTime <= %@ AND endTime >= %@", date, date];
    
    return [[[self.meals set] filteredSetUsingPredicate:predicate] anyObject];
}

- (DiningMeal *)bestMealForDate:(NSDate *)date {
    
    // get current meal if one is occurring now
    DiningMeal *meal = [self mealForDate:date];
    
    if (!meal) {
        // get next meal to begin
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"startTime >= %@", date];
        // array keeps order intact, could also use sortdescriptor
        NSArray *meals = [[self.meals array] filteredArrayUsingPredicate:predicate];
        if ([meals count] > 0) {
            meal = meals[0];
        }
    }
    
    if (!meal) {
        // get last meal of the day
        meal = [self.meals lastObject];
    }
    
    return meal;
}

- (NSString *)statusStringRelativeToDate:(NSDate *)date {
    //      Returns hall status relative to the curent time of day.
    //      Example return strings
    //          - Closed for the day
    //          - Opens at 5:30pm
    //          - Open until 4pm
    
    // If there's a message, it wins.
    // This is important for places like La Verde's which list their hours as "Open 24 Hours".
    if (self.message) {
        return self.message;
    }
    
    DiningMeal *bestMeal = [self bestMealForDate:date];
    
    if (bestMeal.startTime && bestMeal.endTime) {
        // need to calculate if the current time is before opening, before closing, or after closing
        BOOL isBeforeStart = ([bestMeal.startTime compare:date] == NSOrderedDescending);
        BOOL isBeforeEnd   = ([bestMeal.endTime compare:date] == NSOrderedDescending);
        
        if (isBeforeStart) {
            // now-start-end
            return [NSString stringWithFormat:@"Opens at %@", [bestMeal.startTime MITShortTimeOfDayString]];
        } else if (isBeforeEnd) {
            // start-now-end
            return [NSString stringWithFormat:@"Open until %@", [bestMeal.endTime MITShortTimeOfDayString]];
        }
    }
    
    // start-end-now or ?-now-?
    
    // if there's no meals today
    return @"Closed for the day";
}

@end
