#import <Foundation/Foundation.h>
#import "AddOnsSources.h"
#include <stdio.h>
#include <stdlib.h>

#define CHECK(...) do { if (!(__VA_ARGS__)) { fprintf(stderr, "wago check failed: %s\n", #__VA_ARGS__); abort(); } } while (0)

@interface TKAddOnsSources (WagoTest)
- (TKAddOnSearchResult *)wagoResultFromHTML:(NSString *)html slug:(NSString *)slug error:(NSError **)error;
@end

int main(void) {
    @autoreleasepool {
        NSString *html = @"<html><body><div data-page=\"{&quot;props&quot;:{&quot;addon&quot;:{&quot;display_name&quot;:&quot;Test Wago&quot;,&quot;summary&quot;:&quot;A test add-on&quot;,&quot;slug&quot;:&quot;testwago&quot;},&quot;metadata&quot;:{&quot;developers&quot;:[{&quot;name&quot;:&quot;Tester&quot;}],&quot;recent_releases&quot;:{&quot;forever&quot;:{&quot;label&quot;:&quot;v1.2&quot;,&quot;download_link&quot;:&quot;https://example.com/test.zip&quot;,&quot;supported_forever_patches&quot;:[&quot;1.60.1&quot;]}}}}}\"></div></body></html>";
        NSError *error = nil;
        TKAddOnsSources *sources = [[TKAddOnsSources alloc] initWithGameVersion:@"1.60.1" wagoFlavor:@"forever"];
        TKAddOnSearchResult *result = [sources wagoResultFromHTML:html slug:@"testwago" error:&error];
        CHECK(result != nil);
        CHECK(result.source == TKAddOnSourceWago);
        CHECK([result.name isEqualToString:@"Test Wago"]);
        CHECK([result.version isEqualToString:@"v1.2"]);
        CHECK([result.author isEqualToString:@"Tester"]);
        CHECK([result.directURL.absoluteString isEqualToString:@"https://example.com/test.zip"]);
        CHECK([result.pageURL containsString:@"/addons/testwago"]);
        CHECK(result.compatible);

        TKAddOnsSources *retail = [[TKAddOnsSources alloc] initWithGameVersion:@"11.0.5" wagoFlavor:@"retail"];
        TKAddOnSearchResult *retailResult = [retail wagoResultFromHTML:html slug:@"testwago" error:&error];
        CHECK(retailResult != nil);
        CHECK(!retailResult.compatible);
        CHECK(retailResult.compatibilityNote.length > 0);

        TKAddOnsSources *newer = [[TKAddOnsSources alloc] initWithGameVersion:@"1.60.2" wagoFlavor:@"forever"];
        TKAddOnSearchResult *newerResult = [newer wagoResultFromHTML:html slug:@"testwago" error:&error];
        CHECK(newerResult != nil);
        CHECK(!newerResult.compatible);

        printf("wago source: ok\n");
    }
    return 0;
}
