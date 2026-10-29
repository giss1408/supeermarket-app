import 'package:api_client/src/model/card.dart';
import 'package:api_client/src/model/category.dart';
import 'package:api_client/src/model/error.dart';
import 'package:api_client/src/model/flyer_detail.dart';
import 'package:api_client/src/model/flyer_list.dart';
import 'package:api_client/src/model/image_upload_result.dart';
import 'package:api_client/src/model/list_item.dart';
import 'package:api_client/src/model/list_item_request.dart';
import 'package:api_client/src/model/logout_request.dart';
import 'package:api_client/src/model/me.dart';
import 'package:api_client/src/model/offer.dart';
import 'package:api_client/src/model/offer_fields.dart';
import 'package:api_client/src/model/offer_fields_request.dart';
import 'package:api_client/src/model/opening_hours.dart';
import 'package:api_client/src/model/opening_hours_write.dart';
import 'package:api_client/src/model/opening_hours_write_request.dart';
import 'package:api_client/src/model/paginated_category_list.dart';
import 'package:api_client/src/model/paginated_flyer_list_list.dart';
import 'package:api_client/src/model/paginated_offer_list.dart';
import 'package:api_client/src/model/paginated_payment_method_list.dart';
import 'package:api_client/src/model/paginated_shopping_list_list.dart';
import 'package:api_client/src/model/paginated_staff_category_list.dart';
import 'package:api_client/src/model/paginated_staff_flyer_list_list.dart';
import 'package:api_client/src/model/paginated_staff_offer_list.dart';
import 'package:api_client/src/model/paginated_staff_payment_method_list.dart';
import 'package:api_client/src/model/paginated_staff_product_list.dart';
import 'package:api_client/src/model/paginated_staff_store_list.dart';
import 'package:api_client/src/model/paginated_store_list.dart';
import 'package:api_client/src/model/patched_list_item_request.dart';
import 'package:api_client/src/model/patched_me_request.dart';
import 'package:api_client/src/model/patched_shopping_list_detail_request.dart';
import 'package:api_client/src/model/patched_staff_category_request.dart';
import 'package:api_client/src/model/patched_staff_flyer_request.dart';
import 'package:api_client/src/model/patched_staff_offer_request.dart';
import 'package:api_client/src/model/patched_staff_payment_method_request.dart';
import 'package:api_client/src/model/patched_staff_product_request.dart';
import 'package:api_client/src/model/patched_staff_store_request.dart';
import 'package:api_client/src/model/payment_method.dart';
import 'package:api_client/src/model/product.dart';
import 'package:api_client/src/model/product_summary.dart';
import 'package:api_client/src/model/register.dart';
import 'package:api_client/src/model/register_request.dart';
import 'package:api_client/src/model/shopping_list.dart';
import 'package:api_client/src/model/shopping_list_detail.dart';
import 'package:api_client/src/model/shopping_list_detail_request.dart';
import 'package:api_client/src/model/staff_category.dart';
import 'package:api_client/src/model/staff_category_request.dart';
import 'package:api_client/src/model/staff_flyer.dart';
import 'package:api_client/src/model/staff_flyer_list.dart';
import 'package:api_client/src/model/staff_flyer_request.dart';
import 'package:api_client/src/model/staff_offer.dart';
import 'package:api_client/src/model/staff_offer_request.dart';
import 'package:api_client/src/model/staff_payment_method.dart';
import 'package:api_client/src/model/staff_payment_method_request.dart';
import 'package:api_client/src/model/staff_product.dart';
import 'package:api_client/src/model/staff_product_request.dart';
import 'package:api_client/src/model/staff_store.dart';
import 'package:api_client/src/model/staff_store_request.dart';
import 'package:api_client/src/model/store.dart';
import 'package:api_client/src/model/store_detail.dart';
import 'package:api_client/src/model/token_obtain_pair.dart';
import 'package:api_client/src/model/token_obtain_pair_request.dart';
import 'package:api_client/src/model/token_refresh.dart';
import 'package:api_client/src/model/token_refresh_request.dart';

final _regList = RegExp(r'^List<(.*)>$');
final _regSet = RegExp(r'^Set<(.*)>$');
final _regMap = RegExp(r'^Map<String,(.*)>$');

ReturnType deserialize<ReturnType, BaseType>(dynamic value, String targetType,
    {bool growable = true}) {
  switch (targetType) {
    case 'String':
      return '$value' as ReturnType;
    case 'int':
      return (value is int ? value : int.parse('$value')) as ReturnType;
    case 'bool':
      if (value is bool) {
        return value as ReturnType;
      }
      final valueString = '$value'.toLowerCase();
      return (valueString == 'true' || valueString == '1') as ReturnType;
    case 'double':
      return (value is double ? value : double.parse('$value')) as ReturnType;
    case 'Card':
      return Card.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Category':
      return Category.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Error':
      return Error.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'FlyerDetail':
      return FlyerDetail.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'FlyerList':
      return FlyerList.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ImageUploadResult':
      return ImageUploadResult.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ListItem':
      return ListItem.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ListItemRequest':
      return ListItemRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'LogoutRequest':
      return LogoutRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Me':
      return Me.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'Offer':
      return Offer.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'OfferFields':
      return OfferFields.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'OfferFieldsRequest':
      return OfferFieldsRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OpeningHours':
      return OpeningHours.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'OpeningHoursWrite':
      return OpeningHoursWrite.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'OpeningHoursWriteRequest':
      return OpeningHoursWriteRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedCategoryList':
      return PaginatedCategoryList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedFlyerListList':
      return PaginatedFlyerListList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedOfferList':
      return PaginatedOfferList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedPaymentMethodList':
      return PaginatedPaymentMethodList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedShoppingListList':
      return PaginatedShoppingListList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedStaffCategoryList':
      return PaginatedStaffCategoryList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedStaffFlyerListList':
      return PaginatedStaffFlyerListList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedStaffOfferList':
      return PaginatedStaffOfferList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedStaffPaymentMethodList':
      return PaginatedStaffPaymentMethodList.fromJson(
          value as Map<String, dynamic>) as ReturnType;
    case 'PaginatedStaffProductList':
      return PaginatedStaffProductList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedStaffStoreList':
      return PaginatedStaffStoreList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaginatedStoreList':
      return PaginatedStoreList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedListItemRequest':
      return PatchedListItemRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedMeRequest':
      return PatchedMeRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedShoppingListDetailRequest':
      return PatchedShoppingListDetailRequest.fromJson(
          value as Map<String, dynamic>) as ReturnType;
    case 'PatchedStaffCategoryRequest':
      return PatchedStaffCategoryRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedStaffFlyerRequest':
      return PatchedStaffFlyerRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedStaffOfferRequest':
      return PatchedStaffOfferRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedStaffPaymentMethodRequest':
      return PatchedStaffPaymentMethodRequest.fromJson(
          value as Map<String, dynamic>) as ReturnType;
    case 'PatchedStaffProductRequest':
      return PatchedStaffProductRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PatchedStaffStoreRequest':
      return PatchedStaffStoreRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'PaymentMethod':
      return PaymentMethod.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'Product':
      return Product.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ProductSummary':
      return ProductSummary.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ProviderEnum':
    case 'Register':
      return Register.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'RegisterRequest':
      return RegisterRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'RoleEnum':
    case 'ShoppingList':
      return ShoppingList.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'ShoppingListDetail':
      return ShoppingListDetail.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'ShoppingListDetailRequest':
      return ShoppingListDetailRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffCategory':
      return StaffCategory.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffCategoryRequest':
      return StaffCategoryRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffFlyer':
      return StaffFlyer.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'StaffFlyerList':
      return StaffFlyerList.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffFlyerRequest':
      return StaffFlyerRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffOffer':
      return StaffOffer.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'StaffOfferRequest':
      return StaffOfferRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffPaymentMethod':
      return StaffPaymentMethod.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffPaymentMethodRequest':
      return StaffPaymentMethodRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffProduct':
      return StaffProduct.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'StaffProductRequest':
      return StaffProductRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StaffStore':
      return StaffStore.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'StaffStoreRequest':
      return StaffStoreRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'StatusEnum':
    case 'Store':
      return Store.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'StoreDetail':
      return StoreDetail.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'TokenObtainPair':
      return TokenObtainPair.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TokenObtainPairRequest':
      return TokenObtainPairRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    case 'TokenRefresh':
      return TokenRefresh.fromJson(value as Map<String, dynamic>) as ReturnType;
    case 'TokenRefreshRequest':
      return TokenRefreshRequest.fromJson(value as Map<String, dynamic>)
          as ReturnType;
    default:
      RegExpMatch? match;

      if (value is List && (match = _regList.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
            .map<BaseType>((dynamic v) => deserialize<BaseType, BaseType>(
                v, targetType,
                growable: growable))
            .toList(growable: growable) as ReturnType;
      }
      if (value is Set && (match = _regSet.firstMatch(targetType)) != null) {
        targetType = match![1]!; // ignore: parameter_assignments
        return value
            .map<BaseType>((dynamic v) => deserialize<BaseType, BaseType>(
                v, targetType,
                growable: growable))
            .toSet() as ReturnType;
      }
      if (value is Map && (match = _regMap.firstMatch(targetType)) != null) {
        targetType = match![1]!.trim(); // ignore: parameter_assignments
        return Map<String, BaseType>.fromIterables(
          value.keys as Iterable<String>,
          value.values.map((dynamic v) => deserialize<BaseType, BaseType>(
              v, targetType,
              growable: growable)),
        ) as ReturnType;
      }
      break;
  }
  throw Exception('Cannot deserialize');
}
