# mydata_client.model.DuplicatePairOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**contacts** | [**List<ContactOut>**](ContactOut.md) | the two contacts of yours, in name order | [default to const []]
**emails** | **List<String>** | the emails they share, as the first contact writes them | [optional] [default to const []]
**phones** | **List<String>** | the phone numbers they share, as the first contact writes them | [optional] [default to const []]
**signals** | **List<String>** | what they share: email, phone, name | [default to const []]
**strength** | **String** | strong (the same email or phone, under the same name or where one has none) or suggestion (the same name only, or an email or phone shared under another name) | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


