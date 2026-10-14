# mydata_client.model.FollowedSaveIn

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**contact** | [**ContactIn**](ContactIn.md) | the values chosen, as an edit (PATCH /contacts/{id}) takes them | 
**followed** | [**List<FollowedSeenIn>**](FollowedSeenIn.md) | the changed copies the user reviewed: their mark is cleared | [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


