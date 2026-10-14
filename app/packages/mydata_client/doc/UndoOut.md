# mydata_client.model.UndoOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**contact** | [**ContactDetailOut**](ContactDetailOut.md) | the contact as it is after the undo (for a merge: the first original, restored) | 
**contactIds** | **List<String>** | every contact the undo changed: for a merge, each original (restored) and the merged contact (moved to Recently deleted) | [optional] [default to const []]
**undoId** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


