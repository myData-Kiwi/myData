# mydata_client.model.FollowedChangeOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**accountId** | **String** | the followed source (GET /sources): \"mac\" or an iCloud account id | 
**differences** | **List<String>** | what differs from the contact of yours, after normalising (case, spacing, emails in lower case, phones in E.164), in a contact page's order: name, nickname, company, job_title, phone, email, address, birthday, url, note (not for This Mac, which reads no notes), photo, other (any other detail) | [default to const []]
**followed** | [**ContactDetailOut**](ContactDetailOut.md) | the followed copy as it is now (hidden from lists while the contact stands for it) | 
**sourceLabel** | **String** | that source inside a sentence (\"the iCloud account you@example.com\", \"this Mac\") | 

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


