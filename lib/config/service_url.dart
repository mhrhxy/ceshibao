
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