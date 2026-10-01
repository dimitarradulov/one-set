#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "OneSetLogo" asset catalog image resource.
static NSString * const ACImageNameOneSetLogo AC_SWIFT_PRIVATE = @"OneSetLogo";

/// The "WelcomeGym" asset catalog image resource.
static NSString * const ACImageNameWelcomeGym AC_SWIFT_PRIVATE = @"WelcomeGym";

#undef AC_SWIFT_PRIVATE
