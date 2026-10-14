# mydata_client.model.TrashItemOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**backupsKeptUntil** | **String** | YYYY-MM-DD: copies of it in the host's snapshots are kept until this day if it is deleted for good now, while the host keeps running (the apps say so before deleting it for good) | 
**contact** | [**ContactOut**](ContactOut.md) | for kind contact | [optional] 
**deletedAt** | **String** |  | 
**id** | **String** |  | 
**kind** | **String** | what the item is (events come later) | 
**purgeAfter** | **String** | when it is deleted for good (UTC) | 
**title** | **String** | the item's name as the apps show it | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


