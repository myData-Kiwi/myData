# mydata_client.model.CoverageOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**accountId** | **String** |  | 
**complete** | **bool** | true when the source holds every day asked for | 
**coveredEnd** | **String** | last day the source holds (included); none: no limit | [optional] 
**coveredStart** | **String** | first day the source holds; none: no limit | [optional] 
**reason** | **String** | when the source holds no days at all: why | [optional] 
**source_** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


