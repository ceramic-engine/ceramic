#import <Foundation/Foundation.h>
#import "linc_NativeMac.h"

namespace backend {

    void NativeMac_setAppleMomentumScrollSupported(bool value) {

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *appDefaults = [NSDictionary dictionaryWithObject:(value ? @"YES" : @"NO")
        forKey:@"AppleMomentumScrollSupported"];
        [defaults registerDefaults:appDefaults];

    }

}

