//
//  FMDatabase+Category.m
//  YXIM
//
//  Created by Rex on 2019/4/25.
//  Copyright © 2019 yunxiang. All rights reserved.
//

#import "FMDatabase+Category.h"

#define kFMDB_PrintLine @"\n--------------------------------------------------------------------------------------------\n"

#define kFMDB_Print(name, success, sql) NSLog(@"%@ FMDB -> %@ %@ %@ \n\n %@ %@", kFMDB_PrintLine, name, NSStringFromSelector(_cmd), success ? @"success" : @"fail", sql, kFMDB_PrintLine);

#define kFMDB_ToStr(obj) ([obj isKindOfClass:[NSNull class]] || obj == nil) ? @"": [NSString stringWithFormat:@"%@", obj]

dispatch_queue_t fmdb_queue() {
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.fmdb.rxconcurrentqueue", DISPATCH_QUEUE_CONCURRENT);
    });
    return queue;
}

void fmdb_async_queue(dispatch_block block) {
    dispatch_async(fmdb_queue(), ^() {
        block();
    });
}

void fmdb_sync_queue(dispatch_block block) {
    dispatch_sync(fmdb_queue(), ^() {
        block();
    });
}

NSString * const DBNULL = @"_DBNULL";

@implementation FMDatabase (Category)

+ (id)databaseWithName:(NSString *)name path:(NSString *)path {
    BOOL isExist = [[NSFileManager defaultManager] fileExistsAtPath:path];
    if (!isExist) { // 中间有空的子路径的话 fmdb不能直接创建 会报错 error:14
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString * dbPath = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db", name]];
    NSLog(@"%@[%@ path] 数据库路径 %@ %@", kFMDB_PrintLine,[self class], dbPath, kFMDB_PrintLine);
    return [self databaseWithPath:dbPath];
}

@end

@implementation FMDatabaseQueue (Category)

- (void)createTable:(NSString *)name columns:(NSArray *)columns primaryIndex:(NSUInteger)index {
    if (columns.count <= 0) {
        kFMDB_Print(name, NO, @"COLUMNS KEY IS NULL") return;
    }
    if (columns.count <= index) {
        kFMDB_Print(name, NO, @"PRIMARY KEY IS INVALIDATE") return;
    }
    
    NSString * sql_head = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ ", name];
    NSString * sql_columns = [[columns componentsJoinedByString:@" TEXT, "] stringByAppendingString:@" TEXT"];
    NSString * keyColumn = columns[index];
    sql_columns = [sql_columns stringByReplacingOccurrencesOfString:[keyColumn stringByAppendingString:@" TEXT,"] withString:[keyColumn stringByAppendingString:@" TEXT PRIMARY KEY NOT NULL,"]];

    NSString * sql = [NSString stringWithFormat:@"%@(%@)", sql_head, sql_columns];
    [self inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        BOOL success = [db executeUpdate:sql];
        kFMDB_Print(name, success, sql)
    }];
}

- (void)createTable:(NSString *)name columns:(NSArray *)columns primaryIndexs:(NSArray *)indexs {
    if (columns.count <= 0) {
        kFMDB_Print(name, NO, @"COLUMNS KEY IS NULL") return;
    }
    NSMutableArray * keyColumns = [[NSMutableArray alloc] init];
    for (int i = 0; i < indexs.count; i ++) {
        NSInteger index = [indexs[i] integerValue];
        if (columns.count <= i) {
            kFMDB_Print(name, NO, @"PRIMARY KEY IS INVALIDATE") return;
        } else {
            [keyColumns addObject:columns[index]];
        }
    }
    NSString * sql_head = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ ", name];
    NSString * sql_columns = [[columns componentsJoinedByString:@" TEXT, "] stringByAppendingString:@" TEXT"];
    NSString * sql_primarykey = [NSString stringWithFormat:@", PRIMARY KEY (%@)", [keyColumns componentsJoinedByString:@", "]];
    NSString * sql = [NSString stringWithFormat:@"%@(%@%@)", sql_head, sql_columns, sql_primarykey];
    [self inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        BOOL success = [db executeUpdate:sql];
        kFMDB_Print(name, success, sql)
    }];
}

- (void)replaceIntoTable:(NSString *)name columns:(NSArray *)columns values:(NSArray *)values {
    NSString * keyString = [columns componentsJoinedByString:@", "];
    NSString * valueString = [values componentsJoinedByString:@"\", \""];
    NSString * sql = [NSString stringWithFormat:@"REPLACE INTO %@ (%@) VALUES (\"%@\")", name, keyString, valueString];
    sql = [sql stringByReplacingOccurrencesOfString:@"\"NULL\"" withString:@"NULL"];
    [self inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        BOOL success = [db executeUpdate:sql];
        kFMDB_Print(name, success, sql)
    }];
}

- (void)replaceIntoTable:(NSString *)name columns:(NSArray *)columns infoArray:(NSArray <NSDictionary *>*)infos block:(void(^)(BOOL success))block {
    if (infos.count == 0) {
        block(YES); return;
    }
    
    fmdb_async_queue(^{
        NSMutableString * SQL = [[NSMutableString alloc] init];
        [SQL appendFormat:@"REPLACE INTO %@ (%@) VALUES ", name, [columns componentsJoinedByString:@", "]];
        
        NSMutableArray * valuesqls = [[NSMutableArray alloc] init];
        for (NSDictionary * info in infos) {
            NSArray * valuesByInfo = [info objectsForKeys:columns notFoundMarker:@"NULL"];
            NSString * valuesString = [NSString stringWithFormat:@"(\"%@\")", [valuesByInfo componentsJoinedByString:@"\", \""]];
            [valuesqls addObject:valuesString];
        }
        NSString * valuesqlsString = [[valuesqls componentsJoinedByString:@", "] stringByReplacingOccurrencesOfString:@"\"NULL\"" withString:@"NULL"];
        
        [SQL appendString:valuesqlsString];

        [self inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
            BOOL success = [db executeUpdate:SQL];
            kFMDB_Print(name, success, SQL)
            dispatch_async(dispatch_get_main_queue(), ^{
                if (block) block (success);
            });
        }];
    });
}

- (NSInteger)selectCountFromTable:(NSString *)name where:(NSString *)where, ... {
    va_list args;
    va_start(args, where);
    NSString * whereString = [[NSString alloc] initWithFormat:where arguments:args];
    va_end(args);
    
    NSString * sql = [NSString stringWithFormat:@"SELECT count(*) FROM %@%@", name, [self whereStringWith:whereString]];
    __block NSInteger count = 0;
    [self inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet * rs = [db executeQuery:sql];
        while ([rs next]) {
            count = [rs longForColumn:@"count(*)"];
        }
        [rs close];
    }];
    return count;
}

- (NSMutableArray <NSMutableDictionary *> *)selectFromTable:(NSString *)name requireColumns:(NSArray *)columns whereColumn:(NSString *)column in:(NSArray<NSString *> *)values {
    return [self selectFromTable:name requireColumns:columns whereColumn:column in:values orderBy:@"" desc:NO];
}

- (NSMutableArray <NSMutableDictionary *> *)selectFromTable:(NSString *)name requireColumns:(NSArray *)columns whereColumn:(NSString *)column in:(NSArray<NSString *> *)values orderBy:(NSString *)sortColumn desc:(BOOL)isDesc {
    NSString * whereStr = [self whereStringColumn:column withValues:values];
    NSString * orderStr = [self orderStringColumn:column withValue:isDesc];
    NSString * sql = [NSString stringWithFormat:@"SELECT %@ FROM %@%@%@", [columns componentsJoinedByString:@", "], name, [self whereStringWith:whereStr], orderStr];
    return [self selectRequireColumns:columns withSql:sql];
}

- (NSMutableArray <NSMutableDictionary *> *)selectFromTable:(NSString *)name requireColumns:(NSArray *)columns where:(NSString *)where, ... {
    va_list args;
    va_start(args, where);
    NSString * whereString = [[NSString alloc] initWithFormat:where arguments:args];
    va_end(args);
    
    NSString * sql = [NSString stringWithFormat:@"SELECT %@ FROM %@%@", [columns componentsJoinedByString:@", "], name, [self whereStringWith:whereString]];
    return [self selectRequireColumns:columns withSql:sql];
}

- (NSMutableArray <NSMutableDictionary *> *)selectRequireColumns:(NSArray *)columns withSql:(NSString *)sql {

    __block NSMutableArray * mdictArray = [[NSMutableArray alloc] init];
    [self inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        FMResultSet * rs = [db executeQuery:sql];
        while ([rs next]) {
            NSMutableDictionary * mdict = [[NSMutableDictionary alloc] init];
            for (NSString * column in columns) {
                [mdict setValue:kFMDB_ToStr([rs stringForColumn:column]) forKey:column];
            }
            [mdictArray addObject:mdict];
        }
        [rs close];
    }];
    return mdictArray;
}

- (void)updateTable:(NSString *)name columns:(NSArray<NSString *> *)columns values:(NSArray<NSString *> *)values whereColumn:(NSString *)column equal:(NSString *)value {
    if (!columns.count) return;
    NSString * whereStr = [self whereStringColumn:column withValues:@[kFMDB_ToStr(value)]];
    [self updateTable:name columns:columns values:values where:whereStr];
}

- (void)updateTable:(NSString *)name columns:(NSArray<NSString *> *)columns values:(NSArray<NSString *> *)values where:(NSString *)where, ... {
    va_list args;
    va_start(args, where);
    NSString * whereString = [[NSString alloc] initWithFormat:where arguments:args];
    va_end(args);
    
    if (!columns.count) return;
    NSMutableArray * setStrArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < columns.count; i ++) {
        NSString * column_value = [self updateStringColumn:columns[i] withValue:values.count > i ? values[i] : DBNULL];
        [setStrArray addObject:column_value];
    }
    NSString * setStr = [setStrArray componentsJoinedByString:@", "];
    NSString * sql = [NSString stringWithFormat:@"UPDATE %@ SET %@%@", name, setStr, [self whereStringWith:whereString]];
    [self inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        BOOL success = [db executeUpdate:sql];
        kFMDB_Print(name, success, sql);
    }];
}

- (void)deleteFromTable:(NSString *)name whereColumn:(NSString *)column in:(NSArray<NSString *> *)values {
    if (values.count == 0) return;
    
    NSString * whereStr = [self whereStringColumn:column withValues:values];
    [self deleteFromTable:name where:whereStr];
}

- (void)deleteFromTable:(NSString *)name where:(NSString *)where, ... {
    va_list args;
    va_start(args, where);
    NSString * whereString = [[NSString alloc] initWithFormat:where arguments:args];
    va_end(args);
    
    NSString * sql = [NSString stringWithFormat:@"DELETE FROM %@%@", name, [self whereStringWith:whereString]];
    [self inTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
        BOOL success = [db executeUpdate:sql];
        kFMDB_Print(name, success, sql)
    }];
}

#pragma mark - private

- (NSString *)updateStringColumn:(NSString *)column withValue:(NSString *)value  {
    NSString * column_value = @"";
    NSString * valueString = kToStr(value);
    if ([valueString isEqualToString:DBNULL] || ![valueString length]) {
        column_value = [NSString stringWithFormat:@"%@ = NULL", column];
    } else {
        column_value = [NSString stringWithFormat:@"%@ = \"%@\"", column, valueString];
    }
    return column_value;
}

- (NSString *)whereStringColumn:(NSString *)column withValues:(NSArray *)values {
    NSString * whereStr = @"";
    if (column || values.count) {
        if (values.count > 1) {
            NSString * valuesStr = [values componentsJoinedByString:@"', '"];
            valuesStr = [NSString stringWithFormat:@"'%@'", valuesStr];
            whereStr = [NSString stringWithFormat:@"%@ IN (%@) ", column, valuesStr];
        } else {
            whereStr = [NSString stringWithFormat:@"%@ = '%@' ", column, [values firstObject]];
        }
    }
    return whereStr;
}

- (NSString *)whereStringWith:(NSString *)string, ... {
    NSString * whereStr = @"";
    if (string.length > 0) {
        whereStr = [@" WHERE " stringByAppendingString:string];
    }
    return whereStr;
}

- (NSString *)orderStringColumn:(NSString *)column withValue:(BOOL)isDesc {
    NSString * orderStr = @"";
    if (column) {
        orderStr = [NSString stringWithFormat:@" ORDER BY %@ %@", column, isDesc ? @"DESC" : @"ASC"];
    }
    return orderStr;
}

@end

