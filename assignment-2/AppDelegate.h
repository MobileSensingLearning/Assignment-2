//
//  AppDelegate.h
//  assignment-2
//
//  Created by Brandon McFarland on 9/11/18.
//  Copyright © 2018 MobileSensingLearning. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

