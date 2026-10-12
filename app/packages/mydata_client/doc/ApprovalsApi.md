# mydata_client.api.ApprovalsApi

## Load the API package
```dart
import 'package:mydata_client/api.dart';
```

All URIs are relative to *http://127.0.0.1:47821*

Method | HTTP request | Description
------------- | ------------- | -------------
[**approval**](ApprovalsApi.md#approval) | **GET** /approvals/{approval_id} | Approval
[**approvals**](ApprovalsApi.md#approvals) | **GET** /approvals | Approvals
[**decide**](ApprovalsApi.md#decide) | **POST** /approvals/{approval_id} | Decide


# **approval**
> ApprovalOut approval(approvalId)

Approval

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ApprovalsApi();
final approvalId = approvalId_example; // String | 

try {
    final result = api_instance.approval(approvalId);
    print(result);
} catch (e) {
    print('Exception when calling ApprovalsApi->approval: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **approvalId** | **String**|  | 

### Return type

[**ApprovalOut**](ApprovalOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **approvals**
> List<ApprovalOut> approvals(status)

Approvals

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ApprovalsApi();
final status = status_example; // String | 

try {
    final result = api_instance.approvals(status);
    print(result);
} catch (e) {
    print('Exception when calling ApprovalsApi->approvals: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **status** | **String**|  | [optional] 

### Return type

[**List<ApprovalOut>**](ApprovalOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **decide**
> ApprovalOut decide(approvalId, decisionIn)

Decide

### Example
```dart
import 'package:mydata_client/api.dart';
// TODO Configure HTTP Bearer authorization: bearer
// Case 1. Use String Token
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken('YOUR_ACCESS_TOKEN');
// Case 2. Use Function which generate token.
// String yourTokenGeneratorFunction() { ... }
//defaultApiClient.getAuthentication<HttpBearerAuth>('bearer').setAccessToken(yourTokenGeneratorFunction);

final api_instance = ApprovalsApi();
final approvalId = approvalId_example; // String | 
final decisionIn = DecisionIn(); // DecisionIn | 

try {
    final result = api_instance.decide(approvalId, decisionIn);
    print(result);
} catch (e) {
    print('Exception when calling ApprovalsApi->decide: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **approvalId** | **String**|  | 
 **decisionIn** | [**DecisionIn**](DecisionIn.md)|  | 

### Return type

[**ApprovalOut**](ApprovalOut.md)

### Authorization

[bearer](../README.md#bearer)

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

