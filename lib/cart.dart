import 'package:flutter/material.dart';
import 'dingbudaohang.dart'; 
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
/// 比价页面

class Carts extends StatefulWidget {
  const Carts({super.key});

  @override
  State<Carts> createState() => _CartState();
}

class _CartState extends State<Carts> {
  // 显示比价弹框
  void _showCompareDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12.r)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('쿠직 사용법', style: TextStyle(fontSize: 14.sp, color: Colors.grey)),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              _buildDialogItem('C', '쿠팡에서 상품 추가'),
              SizedBox(height: 16.h),
              _buildDialogItem('N', '네이버에서 상품 추가'),
              SizedBox(height: 16.h),
              _buildDialogItem('bag', '다른 쇼핑몰 상품 추가'),
              SizedBox(height: 16.h),
              _buildDialogItem('star', '쿠직 추천 상품'),
              SizedBox(height: 32.h),
            ],
          ),
        );
      },
    );
  }

  // 构建弹框中的项目
  Widget _buildDialogItem(String icon, String text) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Center(
            child: Text(
              icon,
              style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          text,
          style: TextStyle(fontSize: 16.sp, color: Colors.black),
        ),
      ],
    );
  }

  // 构建比价项
  Widget _buildCompareItem(String platform, String price) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(3.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0.5,
            blurRadius: 1,
            offset: Offset(0, 0.5),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左侧平台和商品信息
          Container(
            width: 120.w,
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                // 左侧图标
                Container(
                  width: 20.w,
                  height: 20.h,
                  decoration: BoxDecoration(
                    color: platform == 'C' ? Colors.red : platform == 'N' ? Colors.green : Colors.blue,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                  child: Center(
                    child: platform == 'bag' 
                      ? Icon(Icons.shopping_bag, color: Colors.white, size: 12.r)
                      : Text(
                          platform,
                          style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
                        ),
                  ),
                ),
                SizedBox(width: 12.w),
                // 右侧文字和价格
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 商品图片
                      Container(
                        width: 40.w,
                        height: 25.h,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                        child: Center(
                          child: Image.asset('images/dianplogo.png', width: 20.w, height: 20.h, fit: BoxFit.cover),
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text('xxxxxxxxxx xx', style: TextStyle(fontSize: 8.sp, color: Colors.black)),
                      Text('xxxxxxxxxx', style: TextStyle(fontSize: 8.sp, color: Colors.black)),
                      SizedBox(height: 3.h),
                      Text('$price 韩元', style: TextStyle(fontSize: 10.sp, color: Colors.black, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 右侧商品图片和信息
          Expanded(
            child: Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.only(topRight: Radius.circular(3.r), bottomRight: Radius.circular(3.r)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部标签
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                        color: Colors.white,
                        child: Text('xxxx', style: TextStyle(fontSize: 6.sp)),
                      ),
                      SizedBox(width: 2.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                        color: Colors.white,
                        child: Text('xxxxxx', style: TextStyle(fontSize: 6.sp)),
                      ),
                      SizedBox(width: 2.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                        color: Colors.white,
                        child: Text('xxxxxx', style: TextStyle(fontSize: 6.sp)),
                      ),
                      SizedBox(width: 2.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
                        color: Colors.white,
                        child: Text('xxxx', style: TextStyle(fontSize: 6.sp)),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  // 图片轮播和商品信息并排显示
                  Row(
                    children: [
                      // 左侧图片轮播
                      Container(
                        width: 90.w,
                        child: Column(
                          children: [
                            // 商品图片轮播
                            Container(
                              height: 45.h,
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_back_ios, size: 10.r, color: Colors.black),
                                  SizedBox(width: 4.w),
                                  Container(
                                    width: 60.w,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                    child: Center(
                                      child: Image.asset('images/dianplogo.png', width: 35.w, height: 35.h, fit: BoxFit.cover),
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  Icon(Icons.arrow_forward_ios, size: 10.r, color: Colors.black),
                                ],
                              ),
                            ),
                            // 轮播指示器
                            Container(
                              alignment: Alignment.center,
                              margin: EdgeInsets.symmetric(vertical: 2.h),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(width: 2.w, height: 2.h, decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(1.r))),
                                  SizedBox(width: 2.w),
                                  Container(width: 2.w, height: 2.h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1.r))),
                                  SizedBox(width: 2.w),
                                  Container(width: 2.w, height: 2.h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(1.r))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      // 右侧商品信息和价格
                      Expanded(
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                            Text('xxxxxxxxxxxxxxx xxx', style: TextStyle(fontSize: 8.sp, color: Colors.black)),
                            Text('xxxxxx xxx', style: TextStyle(fontSize: 8.sp, color: Colors.black)),
                            Text('可开发票', style: TextStyle(fontSize: 8.sp, color: Colors.black)),
                            Text('已售 5500+', style: TextStyle(fontSize: 8.sp, color: Colors.black)),
                            SizedBox(height: 4.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('¥ 11', style: TextStyle(fontSize: 10.sp, color: Colors.black, fontWeight: FontWeight.bold)),
                                    Text('2200 韩元', style: TextStyle(fontSize: 8.sp, color: Colors.black, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                Icon(Icons.favorite, size: 12.r, color: Colors.red),
                              ],
                            ),
                          ],
                        ),
                      ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建浏览器打开页面
  Widget _buildBrowserView() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 浏览器顶部导航栏
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('商品详情', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
                Row(
                  children: [
                    Icon(Icons.refresh, size: 16.r, color: Colors.grey),
                    SizedBox(width: 12.w),
                    Icon(Icons.more_vert, size: 16.r, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FixedActionTopBar(),
      body: Column(
        children: [
          // 顶部导航栏
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: _showCompareDialog,
                      child: Text(
                        '比价',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 48.w),
              ],
            ),
          ),
          
          // 下拉选择框
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              children: [
                Text('품목:', style: TextStyle(fontSize: 16.sp, color: Colors.black87)),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Row(
                    children: [
                      Text('전체', style: TextStyle(fontSize: 14.sp)),
                      SizedBox(width: 4.w),
                      Icon(Icons.arrow_drop_down, size: 16.r),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 比价列表
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              children: [
                _buildCompareItem('C', '3000'),
                // 浏览器打开的页面
                _buildBrowserView(),
              ],
            ),
          ),

        ],
      ),
    );
  }


}

