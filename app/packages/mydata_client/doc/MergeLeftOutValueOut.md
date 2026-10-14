# mydata_client.model.MergeLeftOutValueOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**contactId** | **String** | the contact that holds it | 
**kind** | **String** | what the app names it: birthday, job_title, photo, company, nickname, or other | 
**property** | **String** | a vCard property name, upper case (TITLE, BDAY, PHOTO, ...) | 
**value** | **String** | the value as the contact holds it (a birthday as YYYY-MM-DD or --MM-DD); null for a photo | [optional] 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


