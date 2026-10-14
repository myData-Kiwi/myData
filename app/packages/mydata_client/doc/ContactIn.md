# mydata_client.model.ContactIn

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**addresses** | [**List<PostalAddressIn>**](PostalAddressIn.md) |  | [optional] [default to const []]
**birthday** | **String** | YYYY-MM-DD, or --MM-DD when the year is not known | [optional] 
**company** | **String** |  | [optional] 
**department** | **String** |  | [optional] 
**emails** | [**List<LabeledValueIn>**](LabeledValueIn.md) |  | [optional] [default to const []]
**familyName** | **String** |  | [optional] 
**givenName** | **String** |  | [optional] 
**jobTitle** | **String** |  | [optional] 
**middleName** | **String** |  | [optional] 
**namePrefix** | **String** |  | [optional] 
**nameSuffix** | **String** |  | [optional] 
**nickname** | **String** |  | [optional] 
**note** | **String** | may hold line breaks | [optional] 
**phones** | [**List<LabeledValueIn>**](LabeledValueIn.md) |  | [optional] [default to const []]
**urls** | [**List<LabeledValueIn>**](LabeledValueIn.md) |  | [optional] [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


