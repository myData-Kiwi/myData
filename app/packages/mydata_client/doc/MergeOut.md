# mydata_client.model.MergeOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**contact** | [**ContactDetailOut**](ContactDetailOut.md) | the merged contact | 
**leftOut** | [**List<MergeLeftOutOut>**](MergeLeftOutOut.md) | what the others hold that the merged contact does not (a different value of a property it has its own of, or what kind of card it is): names and counts only. The originals keep it until they are deleted for good | [optional] [default to const []]
**merged** | **List<String>** | the originals' ids, now in Recently deleted | [default to const []]
**undoId** | **String** | POST /undo/{undo_id} undoes the merge while nothing changed since | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


