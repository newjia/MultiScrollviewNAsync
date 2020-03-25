//
//  ViewController.m
//  MultScrollViewDemo-ASDK
//
//  Created by newjia on 2017/7/24.
//  Copyright © 2017年 Nils Li. All rights reserved.
//

#import "ViewController.h"
#import <AsyncDisplayKit/AsyncDisplayKit.h>
#import "DemoNode.h"
#import "MJRefresh.h"
#import "YYFPSLabel.h"

@interface ViewController () <ASCollectionDelegate, ASCollectionDataSource, UICollectionViewDelegateFlowLayout>
{
    ASCollectionNode        *mainCollectionNode;
    NSMutableArray          *dataArray;
}
@property (strong, nonatomic) ASCollectionNode        *mainCollectionNode;
@property (strong, nonatomic) NSMutableArray          *dataArray;
@property (nonatomic, assign)   BOOL                        haveMore;

@property (nonatomic, strong) YYFPSLabel *fpsLabel;

@end


@implementation ViewController
@synthesize mainCollectionNode, dataArray;

#define WeakObj(o) autoreleasepool{} __weak typeof(o) o##Weak = o;


- (void)viewDidLoad {
    [super viewDidLoad];

    dataArray = @[].mutableCopy;
 
    [self initCollectionNode];

    [self addRefreshHeader];
    //加载数据
    [self loadData];

    if (@available(iOS 11.0, *)) {
        mainCollectionNode.view.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    } else {
        self.automaticallyAdjustsScrollViewInsets = NO;
    }

        
    //    Demo1: FPS label 用法
        [self testFPSLabel];
}

    
#pragma mark - FPS demo

- (void)testFPSLabel {
    _fpsLabel = [YYFPSLabel new];
    _fpsLabel.frame = CGRectMake(200, 100, 300, 60);
    [_fpsLabel sizeToFit];
    [self.view addSubview:_fpsLabel];
 
}


- (void)addRefreshHeader
{
    mainCollectionNode.view.mj_header = [MJRefreshNormalHeader headerWithRefreshingTarget:self
                                                                          refreshingAction:@selector(loadData)];
}

- (void)addRefreshFooter
{
    mainCollectionNode.view.mj_footer = [MJRefreshAutoNormalFooter  footerWithRefreshingTarget:self
                                                                               refreshingAction:@selector(loadMoreData)];
    mainCollectionNode.view.mj_footer.automaticallyHidden = YES;

}

- (void)initCollectionNode
{
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumLineSpacing = 0;
    layout.minimumInteritemSpacing = 10;
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    mainCollectionNode = [[ASCollectionNode alloc] initWithCollectionViewLayout:layout];
    mainCollectionNode.dataSource = self;
    mainCollectionNode.delegate = self;
    
    mainCollectionNode.backgroundColor = [UIColor whiteColor];
    [self.view addSubnode:mainCollectionNode];

}

- (void)loadData
{
    // 模拟网络请求
    _haveMore = YES;
    @WeakObj(self);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *dataPath = [[NSBundle mainBundle] pathForResource:@"fakeDic.json" ofType:@""];
        NSData *data = [NSData dataWithContentsOfFile:dataPath];
        NSError *error;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
        if (error) {
            NSLog(@"解析失败 -- %@", error);
            return ;
        }
        NSArray *array = [json objectForKey:@"data"];
        [selfWeak.dataArray addObjectsFromArray:array];
        [selfWeak.mainCollectionNode reloadData];

        [selfWeak.mainCollectionNode.view.mj_header endRefreshing];

    });
}
- (void)collectionNode:(ASCollectionNode *)collectionNode willBeginBatchFetchWithContext:(ASBatchContext *)context
{
    [self loadMoreDataWithContext:context];
}

- (void)loadMoreDataWithContext:(ASBatchContext *)context
{
    if (context) {
        [context beginBatchFetching];
    }
    NSString *dataPath = [[NSBundle mainBundle] pathForResource:@"moreFakeDic.json" ofType:@""];
    NSData *data = [NSData dataWithContentsOfFile:dataPath];
    NSError *error;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (error) {
        NSLog(@"解析失败 -- %@", error);
        return ;
    }
    NSLog(@"obj        %@", json);
 
    NSArray *products = [json objectForKey:@"data"];
        if (context) {
            // 加载更多
            if (products.count > 0) {
                NSMutableArray *indexPaths = [NSMutableArray array];
                for (NSInteger row = dataArray.count; row< products.count+ dataArray.count; ++row) {
                    [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
                }

                [dataArray addObjectsFromArray:products];
                __weak typeof(self) weakSelf = self;

                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.mainCollectionNode insertItemsAtIndexPaths:indexPaths];

                });

                _haveMore = YES;
                // 注释掉，无限添加
//                if (products.count < 500) {
//                    _haveMore = NO;
//                    [mainCollectionNode.view.mj_footer endRefreshingWithNoMoreData];
//                }
            }else {
                _haveMore = NO;

                [mainCollectionNode.view.mj_footer endRefreshingWithNoMoreData];
            }
        }

        if (context) {
            [context completeBatchFetching:YES];
        }
}


- (void)loadMoreData
{
    if (_haveMore) {
        [mainCollectionNode.view.mj_footer endRefreshing];
    }else{
        [mainCollectionNode.view.mj_footer endRefreshingWithNoMoreData];
    }
}



#pragma mark - ASCollectionDataSource
- (BOOL)shouldBatchFetchForCollectionNode:(ASCollectionNode *)collectionNode
{
    return  dataArray.count && _haveMore;

}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    mainCollectionNode.frame = CGRectMake(0, 88, self.view.frame.size.width, self.view.frame.size.height - 88);
}

- (NSInteger)collectionNode:(ASCollectionNode *)collectionNode numberOfItemsInSection:(NSInteger)section
{
    return dataArray.count;
}

- (ASCellNodeBlock)collectionNode:(ASCollectionNode *)collectionNode nodeBlockForItemAtIndexPath:(NSIndexPath *)indexPath
{
    @WeakObj(self);

    ASCellNode *(^cellNodeBlock)(void) = ^ASCellNode *(){
        NSDictionary *dic = [NSDictionary dictionary];
        if (selfWeak.dataArray && selfWeak.dataArray.count) {
            dic = selfWeak.dataArray [indexPath.row];
        }
        DemoNode *cellNode = [[DemoNode alloc] initWithData: dic];
        return cellNode;
    };
    return cellNodeBlock;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
