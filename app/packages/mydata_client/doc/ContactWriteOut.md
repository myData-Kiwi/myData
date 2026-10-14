# mydata_client.model.ContactWriteOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**contact** | [**ContactDetailOut**](ContactDetailOut.md) | the contact as it is now (deleted_at set after a delete) | 
**undoId** | **String** | POST /undo/{undo_id} undoes this change; null when nothing changed | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


