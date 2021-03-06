#import "PersistenceManager.h"

@implementation PersistenceManager {
    
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
}

-(id)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeChanges:) name:NSManagedObjectContextDidSaveNotification object:nil];
    }
    return self;
}

-(void)mergeChanges:(NSNotification *)notif {
    [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notif];
}

+(instancetype)sharedInstance {
    static id sharedInstance;
    if (sharedInstance == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedInstance = [[self alloc] init];
        });
    }
    return sharedInstance;
}

+(void)setupPersistence {
    [[self sharedInstance] setupPersistence];
}

+(NSManagedObjectContext *)managedObjectContext {
    return [[self sharedInstance] managedObjectContext];
}

+(void)deletePersistentStore {
    [[self sharedInstance] deletePersistentStore];
}

+(void)resetManagedObjectContext {
    [[self sharedInstance] resetManagedObjectContext];
}

+(void)save {
    [self saveContext:[PersistenceManager managedObjectContext]];
}

+(void)saveContext:(NSManagedObjectContext *)context {
    [[self sharedInstance] saveContext:context];
}

+(void)deleteObject:(NSManagedObject *)object {
    [[self sharedInstance] deleteObject:object];
}

+(void)deleteAllObjects {
    [[self sharedInstance] deleteAllObjectsAndSave];
}


-(void)setupPersistence {
    [self managedObjectContext];
}

#pragma mark Boilerplate CoreData

+(NSManagedObjectModel *)managedObjectModel {
    NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:nil];
    return mom;
}

+(NSURL *)persistentStoreURL {
	
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSURL *url = [NSURL fileURLWithPath:[basePath stringByAppendingPathComponent:@"WunderTest"]];
    return url;
}

+(NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    
    static NSPersistentStoreCoordinator *staticCoordinator;
    if (staticCoordinator == nil) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSError *error;
            NSURL *dbPath = [self persistentStoreURL];
            staticCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
            [staticCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:dbPath options:nil error:&error];
            if (error != nil) {
                [NSException raise:YLCoreDataException format:@"Error loading persistent store coordinator: %@", error];
            }
        });
    }
    return staticCoordinator;
}

-(NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext == nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        _managedObjectContext.persistentStoreCoordinator = [PersistenceManager persistentStoreCoordinator];
    }
    return _managedObjectContext;
}

-(void)saveContext:(NSManagedObjectContext *)context {
    NSError *error;
    if (context.hasChanges == YES) {
        [context save:&error];
    }
    
    if (error != nil) {
        NSLog(@"Error saving into managedObjectContext. Message: %@", error.description);
    }
}

-(void)save {
    NSError *saveError = nil;
    if ([_managedObjectContext hasChanges]) {
        [_managedObjectContext save:&saveError];
    }
    if (saveError != nil) {
        [NSException raise:YLCoreDataException format:@"Error saving context %@. Error: %@", _managedObjectContext, saveError];
    }
}

-(void)resetManagedObjectContext {
    self.managedObjectContext = nil;
}

-(void)deletePersistentStore {
    NSURL *persistentStoreURL = [PersistenceManager persistentStoreURL];
    if ([[NSFileManager defaultManager] fileExistsAtPath:persistentStoreURL.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:persistentStoreURL error:NULL];
    }
    persistentStoreCoordinator = nil;
    [self resetManagedObjectContext];
}

-(void)deleteObject:(NSManagedObject *)object {
    [object.managedObjectContext deleteObject:object];
}

-(void)deleteAllObjectsAndSave {
    [self deleteAllObjectsInContext:self.managedObjectContext];
}

-(void)deleteAllObjectsInContext:(NSManagedObjectContext *)context {
    NSManagedObjectModel *mom = [PersistenceManager managedObjectModel];
    NSError *error;
    NSArray *objArray;
    for (NSEntityDescription *entityDesc in mom) {
        NSEntityDescription *ourDesc = [NSEntityDescription entityForName:entityDesc.name inManagedObjectContext:self.managedObjectContext];
        NSFetchRequest *fetch = [NSFetchRequest new];
        fetch.entity = ourDesc;
        objArray = [context executeFetchRequest:fetch error:&error];
        if (objArray != nil) {
            if (error != nil || [objArray respondsToSelector:@selector(count)] == NO) {
                NSLog(@"Error fetching instances of %@ from core data.", entityDesc.name);
                return;
            }
            for (NSManagedObject *obj in objArray) {
                [self.managedObjectContext deleteObject:obj];
            }
        }
    }
    [self save];
    if (error != nil) {
        NSLog(@"Error deleting all instances of %@ from core data.",  mom.entities);
    }
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
