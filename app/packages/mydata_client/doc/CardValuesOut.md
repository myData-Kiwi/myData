# mydata_client.model.CardValuesOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**addresses** | [**List<PostalAddress>**](PostalAddress.md) |  | [optional] [default to const []]
**birthday** | **String** | YYYY-MM-DD, or --MM-DD when the year is not known | [optional] 
**company** | **String** |  | [optional] [default to '']
**department** | **String** |  | [optional] [default to '']
**displayName** | **String** | never empty (organisation, email or phone when the card has no name) | 
**emails** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**familyName** | **String** |  | [optional] [default to '']
**fields** | [**List<ContactFieldGroup>**](ContactFieldGroup.md) | the values grouped as a contact's page shows them: phone, email, address, birthday, url, note | [default to const []]
**fullName** | **String** |  | [optional] [default to '']
**givenName** | **String** |  | [optional] [default to '']
**hasPhoto** | **bool** |  | [optional] [default to false]
**jobTitle** | **String** |  | [optional] [default to '']
**kind** | **String** | individual, org or group | 
**middleName** | **String** |  | [optional] [default to '']
**namePrefix** | **String** |  | [optional] [default to '']
**nameSuffix** | **String** |  | [optional] [default to '']
**nickname** | **String** |  | [optional] [default to '']
**note** | **String** |  | [optional] [default to '']
**organisation** | **String** | the company and, after a comma, the department | [optional] [default to '']
**phones** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]
**urls** | [**List<LabeledValue>**](LabeledValue.md) |  | [optional] [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


