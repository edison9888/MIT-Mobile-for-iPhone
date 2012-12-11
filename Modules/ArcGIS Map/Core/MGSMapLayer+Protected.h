#import "MGSLayer.h"
#import <ArcGIS/ArcGIS.h>

@class MGSMapView;

@interface MGSLayer ()
@property (nonatomic,weak) MGSMapView *mapView;
@property (nonatomic,weak) UIView<AGSLayerView> *graphicsView;
@property (nonatomic,strong) AGSGraphicsLayer *graphicsLayer;
@property (nonatomic,strong) AGSRenderer *renderer;
@property (nonatomic,readonly) BOOL hasGraphicsLayer;
@property (nonatomic,strong) NSMutableArray *layerAnnotations;

- (void)loadGraphicsLayer;
@end