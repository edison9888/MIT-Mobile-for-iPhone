#import "DiningRetailInfoViewController.h"
#import "DiningHallDetailHeaderView.h"
#import "UIKit+MITAdditions.h"
#import "Foundation+MITAdditions.h"
#import "RetailVenue.h"
#import "RetailDay.h"
#import "CoreDataManager.h"

@interface DiningRetailInfoViewController () <UIWebViewDelegate>

@property (nonatomic, strong) DiningHallDetailHeaderView * headerView;
@property (nonatomic, strong) NSString * descriptionHtmlFormatString;
@property (nonatomic, assign) CGFloat descriptionHeight;

@property (nonatomic, strong) NSArray * sectionData;

@property (nonatomic, strong) NSArray * formattedHoursData;

@end

@implementation DiningRetailInfoViewController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return NO;
}

- (BOOL) shouldAutorotate
{
    return NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = self.venue.shortName;
    
    self.headerView = [[DiningHallDetailHeaderView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.tableView.bounds), 87)];
    self.headerView.titleLabel.text = self.venue.name;
    [self.headerView.accessoryButton setImage:[UIImage imageNamed:@"global/bookmark_off"] forState:UIControlStateNormal];
    [self.headerView.accessoryButton setImage:[UIImage imageNamed:@"global/bookmark_on"] forState:UIControlStateSelected];
    [self.headerView.accessoryButton addTarget:self action:@selector(favoriteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.headerView.accessoryButton.selected = [self.venue.favorite boolValue];
    
    if ([self.venue isOpenNow]) {
        self.headerView.timeLabel.textColor = [UIColor colorWithHexString:@"#008800"];
    } else {
        self.headerView.timeLabel.textColor = [UIColor colorWithHexString:@"#bb0000"];
    }
    
    RetailDay *currentDay = [self.venue dayForDate:[NSDate fakeDateForDining]];
    self.headerView.timeLabel.text = [currentDay statusStringRelativeToDate:[NSDate fakeDateForDining]];
    
    self.descriptionHtmlFormatString = @"<html>"
                                        "<head>"
                                        "<style type=\"text/css\" media=\"screen\">"
                                        "body { margin: 0; padding: 0; font-family: Helvetica; font-size: 13px; } "
                                        "</style>"
                                        "</head>"
                                        "<body id=\"content\">"
                                        "%@"
                                        "</body>"
                                        "</html>";
    self.descriptionHeight = 44;
    
    self.tableView.tableHeaderView = self.headerView;

}

static const NSString * sectionIdKey = @"section_id";
static const NSString * sectionDataKey = @"section_data";

- (void) parseVenueDataIntoSections
{
    NSArray *whiteKeys = @[@"description_html", @"menu_html", @"menu_url", @"hours", @"cuisine", @"payment", @"location", @"homepage_url"];     // whitelist of dictionary keys that will correspond to order in table
    NSMutableArray * sections = [NSMutableArray array];
    
//    for (NSString *key in whiteKeys) {
//        if (self.venueData[key]) {
//            if ([key isEqualToString:@"hours"]) {
//                // hours data is treated differently because raw data is too ugly to show the user.
//                [self parseHoursDataIntoFormat:self.venueData[key]];
//            }
//            
//            NSDictionary * sectionData = @{sectionIdKey : key, sectionDataKey : self.venueData[key]};
//            [sections addObject:sectionData];
//        }
//    }
    self.sectionData = sections;
}

- (void) parseHoursDataIntoFormat:(NSArray *)rawData
{
    NSArray *weekDays = @[@"monday", @"tuesday", @"wednesday", @"thursday", @"friday", @"saturday", @"sunday"];
    NSMutableArray *hoursArray = [NSMutableArray arrayWithCapacity:[rawData count]];
    NSInteger arrComparisonIndex = 0;  // used to compare items against objects in hoursArray
    for (NSDictionary *item in rawData) {
        if (item[@"start_time"] && item[@"end_time"]) {  // only parse hours that have start time and end time
            
            NSString *day = item[@"day"];
            NSString *startTime = item[@"start_time"];
            NSString * endTime = item[@"end_time"];
        
            NSString *timeFormat = [NSString stringWithFormat:@"%@ - %@", [self formatHourString:startTime], [self formatHourString:endTime]]; // this is the time format we want. need to group days based on this format
            
            if ([hoursArray count] == 0) {
                // base case, no hour yet in hoursArray, no need to increment comparison pointer because want to compare against index 0 next time through
                NSDictionary * newFormatItem = @{@"timeSpan": timeFormat, @"daySpan" : @[day]};
                [hoursArray addObject:newFormatItem];
                continue;
            }
            
            NSMutableDictionary *formatItem = [hoursArray[arrComparisonIndex] mutableCopy];
            if (formatItem && [formatItem[@"timeSpan"] isEqualToString:timeFormat]) {
                // adding day to time format array, update is in placem no need to increment arrHead pointer
                NSMutableArray *daySpan = (formatItem[@"daySpan"]) ? [formatItem[@"daySpan"] mutableCopy] : [NSMutableArray arrayWithCapacity:[rawData count]]; // if exists, get it; if not, make it
                NSString * lastDay = [daySpan lastObject];
                if (lastDay && [weekDays indexOfObject:day] - [weekDays indexOfObject:lastDay] == 1) {
                    [daySpan addObject:day];
                    formatItem[@"daySpan"] = daySpan;
                    hoursArray[arrComparisonIndex] = formatItem;
                    continue;
                }
                
                
            }
            
            // does not match previous time format, need to add new object to hoursArray, and increment the comparison pointer
            NSDictionary * newFormatItem = @{@"timeSpan": timeFormat, @"daySpan" : @[day]};
            [hoursArray addObject:newFormatItem];
            arrComparisonIndex = [hoursArray count] - 1;
            
        } else {
            // will need to handle order correctly
            if (item[@"message"]) {
                NSDictionary * formatItem = @{@"timeSpan": item[@"message"], @"daySpan" : @[item[@"day"]]};
                [hoursArray addObject:formatItem];
                arrComparisonIndex = [hoursArray count] - 1;
            }

        }
    }
    
    self.formattedHoursData = hoursArray;
}

- (NSString *) formatHourString:(NSString *) rawString
{   // takes 24 hour time string and formats it into h:mma
    
    NSArray * components = [rawString componentsSeparatedByString:@":"];
    NSInteger hour = [components[0] integerValue];
    NSInteger minute = [components[1] integerValue];
    
    BOOL isPM = NO;
    if (hour >= 12) {
        hour = (hour - 12 == 0)? 12 : hour - 12;
        isPM = YES;
    }
    
    if (minute == 0) {
        // no minutes, truncate from string
        return [NSString stringWithFormat:@"%i%@", hour, (isPM)? @"pm":@"am"];
    } else {
        return [NSString stringWithFormat:@"%i:%i%@", hour, minute, (isPM)? @"pm":@"am"];
    }
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)favoriteButtonPressed:(UIButton *)button
{
    BOOL isFavorite = ![self.venue.favorite boolValue];
    self.venue.favorite = @(isFavorite);
    button.selected = isFavorite;
    [CoreDataManager saveData];
}

- (NSDictionary *) dayScheduleFromHours:(NSArray *) hours
{
    NSDate *rightNow = [NSDate date];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"EEEE"];
    NSString *dateString = [dateFormat stringFromDate:rightNow];
    
    NSString * dateKey = [dateString lowercaseString];
    
    NSDictionary *todaysHours;
    for (NSDictionary *day in hours) {
        if ([day[@"day"] isEqualToString:dateKey]) {
            todaysHours = day;
        }
    }
    
    if (!todaysHours) {
        // closed with no hours today
        return @{@"isOpen": @NO,
                 @"text" : @"Closed for the day"};
    }
    
    if (todaysHours[@"message"]) {
        return @{@"isOpen": @NO,
          @"text" : todaysHours[@"message"]};
    }
    
    if (todaysHours[@"start_time"] && todaysHours[@"end_time"]) {
        // need to calculate if the current time is before opening, before closing, or after closing
        [dateFormat setDateFormat:@"HH:mm"];
        NSString * openString   = todaysHours[@"start_time"];
        NSString * closeString    = todaysHours[@"end_time"];
        
        NSDate *openDate = [NSDate dateForTodayFromTimeString:openString];
        NSDate *closeDate = [NSDate dateForTodayFromTimeString:closeString];
        
        BOOL willOpen       = ([openDate compare:rightNow] == NSOrderedDescending); // openDate > rightNow , before the open hours for the day
        BOOL currentlyOpen  = ([openDate compare:rightNow] == NSOrderedAscending && [rightNow compare:closeDate] == NSOrderedAscending);  // openDate < rightNow < closeDate , within the open hours
        BOOL hasClosed      = ([rightNow compare:closeDate] == NSOrderedDescending); // rightNow > closeDate , after the closing time for the day
        
        [dateFormat setDateFormat:@"h:mm a"];  // adjust format for pretty printing
        
        if (willOpen) {
            NSString *closedStringFormatted = [dateFormat stringFromDate:openDate];
            return @{@"isOpen": @NO,
                     @"text" : [NSString stringWithFormat:@"Opens at %@", closedStringFormatted]};

        } else if (currentlyOpen) {
            NSString *openStringFormatted = [dateFormat stringFromDate:closeDate];
            return @{@"isOpen": @YES,
                     @"text" : [NSString stringWithFormat:@"Open until %@", openStringFormatted]};
        } else if (hasClosed) {
            return @{@"isOpen": @NO,
                     @"text" : @"Closed for the day"};
        }   
    }
    
    // the just in case
    return @{@"isOpen": @NO,
             @"text" : @"Closed for the day"};
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.sectionData count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSDictionary *sectionDict = self.sectionData[section];
    if ([sectionDict[sectionIdKey] isEqualToString:@"hours"]) {
        return [self.formattedHoursData count];
    }
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier];
    }
    // reuse prevention
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    
    // configure cells style for everything but description cell (which is handled in css)
    cell.textLabel.textColor = [UIColor darkTextColor];
    cell.textLabel.font   = [UIFont fontWithName:@"Helvetica-Bold" size:11];
    
    cell.detailTextLabel.font = [UIFont fontWithName:@"Helvetica" size:13];
    cell.detailTextLabel.numberOfLines = 0;
    
    NSDictionary *sectionData = self.sectionData[indexPath.section];
    if ([sectionData[sectionIdKey] isEqualToString:@"description_html"]) {
        // cell contents are rendered in a webview
        static NSString *DescriptionCellIdentifier = @"DescriptionCell";
        cell = [tableView dequeueReusableCellWithIdentifier:DescriptionCellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:DescriptionCellIdentifier];
        }
        
        UIWebView *existingWebView = (UIWebView *)[cell.contentView viewWithTag:42];
        if (!existingWebView) {
            existingWebView = [[UIWebView alloc] initWithFrame:CGRectMake(10, 10, CGRectGetWidth(cell.bounds) - 40, self.descriptionHeight)];
            existingWebView.delegate = self;
            existingWebView.tag = 42;
            existingWebView.dataDetectorTypes = UIDataDetectorTypeAll;
            [cell.contentView addSubview:existingWebView];
        }
        existingWebView.frame = CGRectMake(10, 10, CGRectGetWidth(cell.bounds) - 40, self.descriptionHeight);
        [existingWebView loadHTMLString:[NSString stringWithFormat:self.descriptionHtmlFormatString, sectionData[sectionDataKey]] baseURL:nil];
        existingWebView.backgroundColor = [UIColor clearColor];
        existingWebView.opaque = NO;
    } else if ([sectionData[sectionIdKey] isEqualToString:@"menu_html"]) {
        cell.textLabel.text = @"menu";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        
    } else if ([sectionData[sectionIdKey] isEqualToString:@"menu_url"]) {
        cell.textLabel.text = @"menu";
        cell.detailTextLabel.text = sectionData[sectionDataKey];
        cell.detailTextLabel.numberOfLines = 1;
        cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewExternal];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        
    } else if ([sectionData[sectionIdKey] isEqualToString:@"hours"]) {
        NSLog(@"%@", sectionData);
        NSDictionary *hoursRow = self.formattedHoursData[indexPath.row];
        NSArray * days = hoursRow[@"daySpan"];
        NSString *dayText;
        if ([days count] > 1) {
            NSString * head = days[0];
            NSString * tail = [days lastObject];
            dayText = [NSString stringWithFormat:@"%@ - %@",[head substringToIndex:3], [tail substringToIndex:3]]; // abbreviates days
        } else {
            dayText = days[0];
        }
        
        cell.textLabel.text = dayText;
        if (hoursRow[@"message"]) {
            cell.detailTextLabel.text = hoursRow[@"message"];
        } else {
            cell.detailTextLabel.text = hoursRow[@"timeSpan"];
        }
        
    } else if ([sectionData[sectionIdKey] isEqualToString:@"location"]) {
         NSLog(@"%@", sectionData);
        cell.textLabel.text = sectionData[sectionIdKey];
    }else if ([sectionData[sectionIdKey] isEqualToString:@"homepage_url"]) {
        cell.textLabel.text = @"homepage";
        cell.detailTextLabel.numberOfLines = 1;
        cell.detailTextLabel.text = sectionData[sectionDataKey];
        cell.accessoryView = [UIImageView accessoryViewWithMITType:MITAccessoryViewExternal];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
                                     
    } else if ([sectionData[sectionIdKey] isEqualToString:@"cuisine"] || [sectionData[sectionIdKey] isEqualToString:@"payment"]) {
        cell.textLabel.text = sectionData[sectionIdKey];
        if ([sectionData[sectionDataKey] isKindOfClass:[NSArray class]]) {
            cell.detailTextLabel.text = [sectionData[sectionDataKey] componentsJoinedByString:@", "];
        } else {
            cell.detailTextLabel.text = sectionData[sectionDataKey];
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    NSDictionary *section = self.sectionData[indexPath.section];
    if ([section[sectionIdKey] isEqualToString:@"description_html"]) {
        return self.descriptionHeight + 10; // add some bottom padding
    }
    
    return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *sectionData = self.sectionData[indexPath.section];
    if ([sectionData[sectionIdKey] isEqualToString:@"menu_html"]) {
        // show menu view controller
        
    } else if ([sectionData[sectionIdKey] isEqualToString:@"menu_url"]) {
        // external url
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:sectionData[sectionDataKey]]];
    } else if ([sectionData[sectionIdKey] isEqualToString:@"location"]) {
        // link to map view
        
    } else if ([sectionData[sectionIdKey] isEqualToString:@"homepage_url"]) {
        // external url
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:sectionData[sectionDataKey]]];
    }
}

#pragma mark - WebViewDelegate
- (void)webViewDidFinishLoad:(UIWebView *)webView
{
	// calculate webView height, if it change we need to reload table
	CGFloat newDescriptionHeight = [[webView stringByEvaluatingJavaScriptFromString:@"document.getElementById(\"content\").scrollHeight;"] floatValue];
    CGRect frame = webView.frame;
    frame.size.height = newDescriptionHeight;
    webView.frame = frame;
    
	if(newDescriptionHeight != self.descriptionHeight) {
		self.descriptionHeight = newDescriptionHeight;
		[self.tableView reloadData];
    }
}


@end
