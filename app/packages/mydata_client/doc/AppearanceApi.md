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

Deprecated, kept for one release (design/themes/ARCHITECTURE.md 4.2): the theme the host gave every app before themes were chosen on each device. Each device reads it once to seed its own choice.

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
> setAppearance()

Set Appearance

Retired: themes are chosen on each device, per app (the device's settings, never the host). Always 410, and the host's stored theme is left as it was.

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
    api_instance.setAppearance();
} catch (e) {
    print('Exception when calling AppearanceApi->setAppearance: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

void (empty response body)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

