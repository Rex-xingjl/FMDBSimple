//
//  FMDatabase+Category.h
//  YXIM
//
//  Created by Rex on 2019/4/25.
//  Copyright © 2019 yunxiang. All rights reserved.
//

#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

NS_ASSUME_NONNULL_BEGIN
typedef void(^dispatch_block)(void);
void fmdb_async_queue(dispatch_block block);

extern NSString * const DBNULL; // 设置成空指针

@interface FMDatabase (Category)

/**
 * 通过name创建数据库
 * 会补充路径中缺失的中间文件目录
 */
+ (id)databaseWithName:(NSString *)name path:(NSString *)path;

@end

@interface FMDatabaseQueue (Category)

#pragma mark - -------------------------- Creat Table ------------------------------

/**
 * 通过name创建数据库表
 *
 * columns 表的列字段
 * index   主键在columns中的位置
 */
- (void)createTable:(NSString *)name
            columns:(NSArray *)columns
       primaryIndex:(NSUInteger)index;

/**
 * 通过name创建数据库表
 *
 * columns  表的列字段
 * indexs   联合主键在columns中的位置
 */
- (void)createTable:(NSString *)name
            columns:(NSArray *)columns
      primaryIndexs:(NSArray *)indexs;

#pragma mark - -------------------------- Replace Into -----------------------------

/**
 * 数据库添加数据 或者替换原数据
 * 同步并发方法 处理单条数据
 *
 * name     表名
 * columns  待更新的列集合
 * values   待更新的数值集合
 */
- (void)replaceIntoTable:(NSString *)name
                 columns:(NSArray *)columns
                  values:(NSArray *)values;

/**
 * 数据库表添加数据 或者替换原数据
 * 异步并发方法 处理多条数据
 *
 * name     表名
 * columns  完整的字段组
 * infos    待更新的数据字典 只会对columns里的字段进行取值
 */
- (void)replaceIntoTable:(NSString *)name
                 columns:(NSArray *)columns
               infoArray:(NSArray <NSDictionary *>*)infos
                   block:(void(^)(BOOL success))block;

#pragma mark - -------------------------- Select From ------------------------------

/**
 * 检索符合条件数据数量
 *
 * columns   需要的列字段 会记录在返回数据中
 */
- (NSInteger)selectCountFromTable:(NSString *)name where:(NSString *)where, ...;

/**
 * 通过sql语句进行检索
 *
 * columns   需要的列字段 会记录在返回数据中
 */
- (NSMutableArray <NSMutableDictionary *> *)selectRequireColumns:(NSArray *)columns
                                                         withSql:(NSString *)sql, ...;

/**
 * 通过数据库表name进行检索 不传检索条件则全部检索
 *
 * columns      需要获取的列字段
 * whereString  数据库where语句的条件 例如 @"id = 1 && name = '2'"
 */
- (NSMutableArray <NSMutableDictionary *> *)selectFromTable:(NSString *)name
                                                requireColumns:(NSArray *)columns
                                                        where:(NSString *)where, ...;

/**
 * 通过数据库表name进行检索 不传检索条件则全部检索
 *
 * columns   需要获取的列字段
 * column    检索条件字段
 * values    满足条件的集合
 */
- (NSMutableArray <NSMutableDictionary *> *)selectFromTable:(NSString *)name
                                             requireColumns:(NSArray<NSString *> *)columns
                                                whereColumn:(NSString * __nullable)column
                                                         in:(NSArray<NSString *> * __nullable)values;

/**
 * 通过数据库表name进行检索 不传检索条件则全部检索
 *
 * columns    需要获取的列字段
 * column     检索条件字段
 * values     满足条件的集合
 * sortColumn 排序字段
 * isDesc     是否为降序排序
 */
- (NSMutableArray <NSMutableDictionary *> *)selectFromTable:(NSString *)name
                                             requireColumns:(NSArray *)columns
                                                whereColumn:(NSString *)column
                                                         in:(NSArray<NSString *> *)values
                                                    orderBy:(NSString *)sortColumn
                                                       desc:(BOOL)isDesc;

#pragma mark - -------------------------- Update Table -----------------------------

/**
 * 通过数据库表name进行更新 不传检索条件则全部更新
 *
 * columns    待更新的列字段
 * values     待更新的数值
 * column     检索条件字段
 * value      条件的值
 */
- (void)updateTable:(NSString *)name
            columns:(NSArray<NSString *> *)columns
             values:(NSArray<NSString *> *)values
        whereColumn:(NSString * __nullable)column
              equal:(NSString * __nullable)value;

/**
 * 通过数据库表name进行更新 不传检索条件则全部更新
 *
 * columns    待更新的列字段
 * values     待更新的数值
 * whereString 数据库where语句的条件 例如 @"id = 1 && name = '2'"
 */
- (void)updateTable:(NSString *)name
            columns:(NSArray<NSString *> *)columns
             values:(NSArray<NSString *> *)values
              where:(NSString *)where, ...;

#pragma mark - -------------------------- Delete From ------------------------------

/**
 * 通过数据库表name进行删除 不传检索条件则全删除
 *
 * column     字段名称
 * values     满足条件的集合
 */
- (void)deleteFromTable:(NSString *)name
            whereColumn:(NSString * __nullable)column
                     in:(NSArray <NSString *> * __nullable)values;

/**
 * 通过数据库表name进行删除 不传检索条件则全删除
 *
 * whereString 数据库where语句的条件 例如 @"id = 1 AND name = '2'"
 */
- (void)deleteFromTable:(NSString *)name
                  where:(NSString *)where, ...;

@end

NS_ASSUME_NONNULL_END
