#import "AboutViewController.h"
#import "../UI/LauncherTheme.h"

@implementation TKAboutViewController

- (instancetype)init {
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.title = @"About";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.view.backgroundColor = TKLauncherTheme.background;
    UITextView *text = [UITextView new];
    text.editable = NO;
    text.backgroundColor = TKLauncherTheme.background;
    text.textColor = TKLauncherTheme.text;
    text.font = TKLauncherTheme.body;
    text.adjustsFontForContentSizeCategory = YES;
    text.textContainerInset = UIEdgeInsetsMake(20, 20, 28, 20);
    NSMutableString *credits = [@"Tolkara — an independent World of Warcraft launcher; the on-device updater is merged from the Wolkara fork. Not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft belongs to Blizzard Entertainment.\n\n" mutableCopy];
    for (NSString *name in @[@"LICENSE", @"NOTICE.md"]) {
        NSString *path = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:name];
        NSString *notice = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
        if (notice) [credits appendFormat:@"%@\n%@\n\n", name, notice];
    }
    text.text = credits;
    self.view = text;
}

@end
