# mydata_client.model.StopFollowingOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**accountId** | **String** |  | 
**calendarsFollowed** | **int** | stopping following the account stops following these too; they are not imported yet | 
**contactsChanged** | **int** | its contacts changed since they were imported (the copy on myData is older) | [optional] [default to 0]
**contactsFollowed** | **int** | its contacts with no copy on myData (skipped, not imported yet): stopping following removes them from myData | 
**contactsLinked** | **int** | its contacts hidden behind a contact of yours kept instead (link), which may hold details yours does not | [optional] [default to 0]
**label** | **String** | the source as a heading | 
**message** | **String** |  | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


