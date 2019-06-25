/////////////////////////////////////////////////////////////////////////////////////////////////////
///	
///  @file       ViewController.m
///  @copyright  Copyright © 2019 小灬豆米. All rights reserved.
///  @brief      ViewController
///  @date       2019/6/23
///  @author     小灬豆米
///
/////////////////////////////////////////////////////////////////////////////////////////////////////

#import "ViewController.h"
#import "PaintView.h"

//CONSTANTS:

#define kBrightness             1.0
#define kSaturation             0.45

#define kPaletteHeight          30
#define kPaletteSize            5
#define kMinEraseInterval       0.5

// Padding for margins
#define kLeftMargin             10.0
#define kTopMargin              10.0
#define kRightMargin            10.0

@interface ViewController ()

@property (nonatomic, strong) PaintView *paintView;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (weak, nonatomic) IBOutlet UIButton *undoButton;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initUI];
}

- (void)initUI {
    self.view.backgroundColor = [UIColor grayColor];
    
    PaintViewConfig *config = [PaintViewConfig new];
    config.defaultWidth = 20;
    config.textureImageName = @"刻刀";
    config.needAddSpeed = NO;
    
    self.paintView = [[PaintView alloc] initWithConfig:config frame:self.view.bounds];
    self.paintView.backgroundColor = [UIColor whiteColor];
//    self.paintView.center = self.view.center;
    [self.view addSubview:self.paintView];
    
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"毛笔",
                                                                                       @"圆尖",
                                                                                       @"扁尖",
                                                                                       @"美工",
                                                                                       @"刻刀"]];
    
    CGRect rect = [[UIScreen mainScreen] bounds];
    CGRect frame = CGRectMake(rect.origin.x + kLeftMargin, rect.size.height - kPaletteHeight - kTopMargin, rect.size.width - (kLeftMargin + kRightMargin), kPaletteHeight);
    segmentedControl.frame = frame;
    // When the user chooses a color, the method changeBrushColor: is called.
    [segmentedControl addTarget:self action:@selector(changeBrushColor:) forControlEvents:UIControlEventValueChanged];
    // Make sure the color of the color complements the black background
    segmentedControl.tintColor = [UIColor darkGrayColor];
    // Set the third color (index values start at 0)
    segmentedControl.selectedSegmentIndex = 2;
    [self.view addSubview:segmentedControl];
    
    [self.view bringSubviewToFront:self.clearButton];
    [self.view bringSubviewToFront:self.undoButton];
}

- (IBAction)undoAction:(UIButton *)sender {
    [self.paintView undo];
}

- (IBAction)clearAction:(UIButton *)sender {
    [self.paintView clear];
}

- (void)changeBrushColor:(UISegmentedControl *)control {
    self.paintView.config.textureImageName = @[@"毛笔",
                                               @"圆尖",
                                               @"扁尖",
                                               @"美工",
                                               @"刻刀"][control.selectedSegmentIndex];
}

@end
