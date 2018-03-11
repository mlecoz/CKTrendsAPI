# SampleDevApp

This repo is a playground of sorts containing the API code necessary for tracking the CloudKit database of "SampleDevApp."
The code of this repo was eventually turned into a Carthage library (also in this repo) to be used in your app in conjunction with the app CKTrends.

## Simplified version of how this works
1) Download the CKTrends API from the Carthage directory in this repo.
2) Add this framework to your own project. (Note: If you're using Cocoapods in your project, and Google Firebase is one of your
dependencies, this won't work.)
3) Follow the documentation below to prepare your project to use this API. Make the appropriate API calls using the documentation
below.
4) Get the CKTrends app by emailing cktrends1@gmail.com. (Unfortunately this app was rejected by the App Store because it was considered an "inappropriate" use of Apple's CloudKit database, as they considered my code to be "scraping" CloudKit. I can still distribute the app ad hoc, however.)
5) Follow the registration instructions in the CKTrends app (also below).
6) Tap "Refresh" in the CKTrends app to open your own app and invoke the API code. Return to the CKTrends app to view a bar
graph with your CloudKit trends!

## Step by step set up


