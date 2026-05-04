# PR: Add retry logic to widget API client

## Summary

In today's distributed systems, network failures are unfortunately common. As we all know, transient errors can cause unnecessary user frustration when they bubble up to the UI. This PR addresses that issue by adding retry logic to the widget API client.

The change might possibly help reduce the rate of failed widget creations, which could perhaps be a significant improvement to user experience. We may want to consider extending this to other API clients somewhat similarly.

## Changes

- Adds exponential backoff retry to `WidgetClient.create()`
- Adds 3-attempt cap with jitter
- Adds metric `widget.retry.count` to track retry frequency

## Testing

Manual testing against the staging widget API confirmed retries fire on simulated 503 responses.
