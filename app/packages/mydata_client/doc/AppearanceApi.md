# mydata_client.api.AppearanceApi

## Load the API package
```dart
import 'package:mydata_client/api.dart';
```

All URIs are relative to *http://127.0.0.1:47821*

Method | HTTP request | Description
------------- | ------------- | -------------
[**appearance**](AppearanceApi.md#appearance) | **GET** /appearance | Appearance
[**setAppearance**](AppearanceApi.md#setappearance) | **PUT** /appearance | Set Appearance


# **appearance**
> AppearanceOut appearance()

Appearance

The theme every app uses, and the themes to choose from. Light or dark mode is per device.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AppearanceApi();

try {
    final result = api_instance.appearance();
    print(result);
} catch (e) {
    print('Exception when calling AppearanceApi->appearance: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**AppearanceOut**](AppearanceOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setAppearance**
> AppearanceOut setAppearance(appearanceIn)

Set Appearance

Set the theme every app uses. Apps follow the change through GET /status.

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = AppearanceApi();
final appearanceIn = AppearanceIn(); // AppearanceIn | 

try {
    final result = api_instance.setAppearance(appearanceIn);
    print(result);
} catch (e) {
    print('Exception when calling AppearanceApi->setAppearance: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **appearanceIn** | [**AppearanceIn**](AppearanceIn.md)|  | 

### Return type

[**AppearanceOut**](AppearanceOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

