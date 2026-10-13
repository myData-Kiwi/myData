# mydata_client.model.EventsOut

## Load the model package
```dart
import 'package:mydata_client/api.dart';
```

## Properties
Name | Type | Description | Notes
------------ | ------------- | ------------- | -------------
**coverage** | [**List<CoverageOut>**](CoverageOut.md) | per source holding calendars, which days it holds. When a source is not complete, events on days outside its range are not known: do not show those days as empty | [default to const []]
**events** | [**List<EventOut>**](EventOut.md) |  | [default to const []]

[[Back to Model list]](../README.md#documentation-for-models) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to README]](../README.md)


