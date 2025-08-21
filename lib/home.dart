import 'package:dio/dio.dart';
import 'package:easy_refresh/easy_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mall/model/home_model.dart';
import 'package:flutter_mall/utils/http_util.dart';

import 'config/service_url.dart';
import 'model/brand_list.dart';


class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {

  // 品牌列表
  List<BrandListData> brandList = [];

  // 秒杀
  HomeFlashPromotion? homeFlashPromotion;
  List<ProductList> flashProductList = [];
  int _count = 4;
  late EasyRefreshController _controller;
  
  get newProductList => null;

  @override
  void initState() {
    super.initState();
    _controller = EasyRefreshController(
      controlFinishRefresh: true,
      controlFinishLoad: true,
    );
    _queryHomeData();
  }

  void _queryHomeData() async {
    Response result = await HttpUtil.get(homeDataUrl);
    setState(() {
      HomeModel homeModel = HomeModel.fromJson(result.data);
      brandList = homeModel.data.brandList;
      homeFlashPromotion = homeModel.data.homeFlashPromotion;
      flashProductList = homeModel.data.homeFlashPromotion.productList;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
      color: Colors.white,
      child: EasyRefresh(
        controller: _controller,
        onRefresh: () async {
          setState(() {
            _count = 6;
          });
          _controller.finishRefresh();
          _controller.resetFooter();
          // return IndicatorResult.success;
        },
        onLoad: () async {
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) {
            return;
          }
          setState(() {
            _count += 2;
          });
          _controller.finishLoad(_count >= 30 ? IndicatorResult.noMore : IndicatorResult.success);
        },
        child: CustomScrollView(
          shrinkWrap: true,
          slivers: [
          ],
        ),
      ),
    ));
  }
}