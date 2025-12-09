
// const baseUrl = "http://10.168.96.23:9999";
const baseUrl = "http://192.168.0.120:8080";
// 首页
const homeDataUrl = "$baseUrl/api/home/index";
// 品牌列表
const brandListDataUrl = "$baseUrl/api/brand/queryBrandList";
// 品牌详情
const brandDetailDataUrl = "$baseUrl/api/brand/queryBrandProductList?brandId=";
// 分类
const categoriesDataUrl = "$baseUrl/api/category/queryProductCateTreeList";
// 购物车
const cartDataUrl = "$baseUrl/api/cart/queryCartList";
// 添加商品进购物车
const cartAddUrl = "$baseUrl/api/cart/addCart";
// 商品列表
const productListDataUrl = "$baseUrl/api/product/queryProductList?productCategoryId=";
// 商品详情
const productDetailDataUrl = "$baseUrl/api/product/queryProduct?productId=";
// 通知消息
const messageListDataUrl = "$baseUrl/api/member/message/list/";
// 优惠券
const couponDataUrl = "$baseUrl/api/member/coupon/queryCouponList?useStatus=";
// 订单列表
const orderListDataUrl = "$baseUrl/api/order/orderList?status=";
// 订单详情
const orderDetailDataUrl = "$baseUrl/api/order/orderDetail?orderId=";
// 收货地址列表
const addressListDataUrl = "$baseUrl/api/member/address/queryMemberAddressList";
// 添加会员地址
const addAddressDataUrl = "$baseUrl/api/member/address/addMemberAddress ";
// 我的足迹
const historyListDataUrl = "$baseUrl/api/history/queryReadHistoryList";
// 我的收藏
const collectionListDataUrl = "$baseUrl/api/collection/queryProductCollectionList";
// 我的关注
const focusOnListDataUrl = "$baseUrl/api/member/attention/queryAttentionList";
// 账号登录
const loginDataUrl = "$baseUrl/member/login";
// 邮箱登录
const logineamilUrl = "$baseUrl/member/email/login";
//发送验证码
const apisendemail = "$baseUrl/email/send";
// 获取用户信息
const memberInfoDataUrl = "$baseUrl/api/member/info";
//注册接口
const apiregister = "$baseUrl/register";
// 重置密码
const resetPasswordUrl = "$baseUrl/member/updatePassword";
// 忘记密码邮箱重置获取验证码
const verifyForgotCodeUrl = "$baseUrl/email/forgetPasswordCheckCode";
// 轮播图片
const  carouselListUrl =  "$baseUrl/system/carousel/list";
// 首页商品分类
const  catelogListUrl =  "$baseUrl/system/catelog/list?level=1";
// 关键词搜索
const  searchByKeyword = "$baseUrl/taobao/product/searchByKeyword";
// 图片搜索
const searchByImage =  "$baseUrl/taobao/product/searchByImage";
// 轮播评论
const observelist =  "$baseUrl/system/observe/list";
// 点击商品分类显示二三级分类
const findCatelogByParentId =  "$baseUrl/system/catelog/findCatelogByParentId?parentId=";
// 淘宝上传图片返回id
const taobaoimg =  "$baseUrl/tabao/img/upload";
// 账户信息变更，获取账户信息
const memberinfo =  "$baseUrl/member/info";
// 账户修改密码 
const updatePassword =  "$baseUrl/member/info/updatePassword";
//退出登录
const logout = "$baseUrl/logout";
//修改账户信息
const updatememberinfo = "$baseUrl/member/info";
// 查询商品详情
const getProductDetail = "$baseUrl/taobao/product/getProductDetail";
// 收藏商品
const getcollect = "$baseUrl/product/collect";
// 取消收藏商品
const reamcollect = "$baseUrl/product/collect/{productId}";
// 查询精彩评论
const listByProductLimit = "$baseUrl/system/observe/listByProductLimit?productId=";
// 查询精彩评论商品所有评论
const listByProductAll = "$baseUrl/system/observe/listByProductAll?productId=";
// 我的评论
const listByMember =   "$baseUrl/system/observe/listByMember";
// 删除回复
const deleteReply =    "$baseUrl/system/observe/deleteReply/{replyIds}";
// 删除评论
const observe =    "$baseUrl/system/observe/{observeIds}";
// 新增评论
const insertObserve =    "$baseUrl/system/observe/insertObserve";
// 用户回复评论
const answer =    "$baseUrl/system/observe/answer";
// 查看评论所有回复
const replyListByObserveId =    "$baseUrl/system/observe/replyListByObserveId?observeId=";
// 点击头像查看用户评价
const listByMembers =    "$baseUrl/system/observe/listByMember?userId=";
// 购物车列表
const cartlist =  "$baseUrl/product/cart/list";
// 添加购物车列表
const productcart =  "$baseUrl/product/cart";
// 删除购物车列表
const revmecartlist =  "$baseUrl/product/cart/{cartIds}";
// 修改购物车列表数量
const unpedcart =  "$baseUrl/product/cart/";
// 收藏列表
const collectlist =  "$baseUrl/product/collect/list";
// 海外运费标准
const feelist =  "$baseUrl/fee/list";
// 商品海外总运费
const feesea =  "$baseUrl/fee/sea";
// 获取淘宝运费
const fee =  "$baseUrl/fee";
// 用户地址详情
const userAddress =  "$baseUrl/system/uaddress/{userAddressId}";
// 获取用户地址
const uaddresslist =  "$baseUrl/system/uaddress/list";
// 删除地址
const removelist =  "$baseUrl/system/uaddress/{userAddressIds}";
// 修改用户地址
const uoputedlist =  "$baseUrl/system/uaddress";
// 查询订单列表
//orderState 1待支付,2已支付,3待发货,4发货中,5已入库,6出库待发,7发货完成,8已到货,9已完成,-1已取消,-2订单异常 0所有
//orderPayState 1未支付,2淘宝支付成功,3支付成功,-1支付失败 0所有
const searchOrderListUrl = "$baseUrl/order/searchOrderList?";
// 根据订单查询订单信息
const searchOrderProductListUrl = "$baseUrl/order/searchOrderProductList?";
// 取消订单
const cancelOrderUrl = "$baseUrl/order/cancelOrder?orderIds=";
// 创建订单
const createOrder= "$baseUrl/order/create";
// 查询汇率
const searchRateUrl = "$baseUrl/system/rate/searchByCurrency";
// 获取所有支付类型
const methodlist = "$baseUrl/order/method/list";
// 支付卡列表查询
const cardlist = "$baseUrl/system/card/list?payMethod=2";
// 卡支付
const cardpay = "$baseUrl/order/cardpay/pay";
// naverpay支付
const naverpay = "$baseUrl/order/naverpay/pay";
// 用户开关自己支付类型
const usermethod = "$baseUrl/order/method";
// 查询公告信息接口
const noticeListUrl = "$baseUrl/system/notice/list";
// 查看公告详情接口
const noticeDetailUrl = "$baseUrl/system/notice/{noticeId}";
// 查询用户通知类型接口
const searchNotifyByUserUrl = "$baseUrl/notify/userManager/searchNotifyByUser";
// 通过类型查询用户通知信息列表接口
const searchNotifyByUserTypeUrl = "$baseUrl/notify/notify/searchNotifyByUser?type=";
// 已读接口
const readNotifyUrl = "$baseUrl/notify/notify";
// 自营商品列表
const selfProductListUrl = "$baseUrl/product/autom/list";
// 自营商品详情
const selfProductDetailUrl = "$baseUrl/product/autom/";
// 退出会员
const exitMemberUrl = "$baseUrl/member/info";
