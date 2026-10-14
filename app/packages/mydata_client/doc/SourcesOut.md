# mydata_client.model.SourcesOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**ownedRevision** | **String** | changes whenever the host's own contacts may have changed (a write, an import or its undo, a merge, a settled review), so an app reads its list again; counts only, no values | [optional] [default to '']
**sources** | [**List<SourceOut>**](SourceOut.md) |  | [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


