# mydata_client.model.ImportOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**addressBookId** | **String** |  | [optional] 
**counts** | **Map<String, Object>** | as ImportCountsOut, plus undo (removed, reverted, unlinked, kept, gone) once undone | [default to const {}]
**finishedAt** | **String** |  | [optional] 
**id** | **String** |  | 
**label** | **String** |  | 
**source_** | **String** |  | 
**sourceAccount** | **String** |  | [optional] 
**startedAt** | **String** |  | 
**status** | **String** | committed or undone | 
**undoneAt** | **String** |  | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


