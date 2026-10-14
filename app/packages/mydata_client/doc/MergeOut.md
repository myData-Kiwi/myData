# mydata_client.model.MergeOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**contact** | [**ContactDetailOut**](ContactDetailOut.md) | the merged contact | 
**merged** | **List<String>** | the originals' ids, now in Recently deleted | [default to const []]
**undoId** | **String** | POST /undo/{undo_id} undoes the merge while nothing changed since | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


