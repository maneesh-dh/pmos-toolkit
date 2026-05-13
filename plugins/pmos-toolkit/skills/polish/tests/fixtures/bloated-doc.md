---
type: prd
---

# Notification preferences — product requirements

## Background and context

It is important to note that, before we dive into the actual requirements, it is worth taking a moment to set the stage and provide some context around why we are even considering this work in the first place. Over the past several quarters, we have heard — repeatedly, and from a wide variety of sources including support tickets, sales calls, and the occasional Twitter thread — that users find our current notification system to be, frankly, somewhat overwhelming. They get too many notifications, the notifications they do get are not always relevant, and there is, at present, no real way for them to tune any of this to their liking. This is, needless to say, not an ideal state of affairs, and it is something that we believe we should address sooner rather than later.

In order to fully appreciate the scope of the problem, it may be helpful to consider a few concrete examples. Imagine, if you will, a user named Sarah. Sarah signed up for our product about a year ago. In the beginning, the notifications were fine — useful, even. But over time, as she joined more projects and more teammates were added to those projects, the volume of notifications she received began to climb, and climb, and climb, until eventually she just turned them all off entirely, which means she now misses the ones that actually matter. Sarah's story is not unique. We have, in fact, dozens of Sarahs.

## Goals

The goal of this project, at a high level, is to give users meaningful control over the notifications they receive. More specifically, and in no particular order, we want to: allow users to choose which categories of events they are notified about; allow users to choose the channel (email, in-app, push) for each category; allow users to set a quiet-hours window during which no notifications are delivered; and provide a sensible set of defaults so that users who never touch any of this still have a reasonable experience out of the box.

## Non-goals

It is probably worth being explicit about what this project is not. This project is not, for the avoidance of doubt, a complete rewrite of the notification delivery infrastructure. It is also not an attempt to build a fully general-purpose rules engine where users can write arbitrary conditions. And it is definitely not, despite what some stakeholders may have hoped, a machine-learning-powered system that magically figures out what each user wants. We are, for now, keeping things simple.

## Requirements

At a minimum, the following requirements must be met. First, there must be a settings page where the user can see all of the notification categories and toggle them on or off. Second, for each category that is toggled on, the user must be able to pick the delivery channel. Third, there must be a quiet-hours setting. Fourth, all of this must respect a set of defaults for new users. Fifth, changes must take effect immediately, or at least within a minute or so, because users get confused if they toggle something and then keep getting the notification.

## Open questions

There are, as always, a number of open questions that we will need to resolve as we go. Should quiet hours be per-channel or global? What happens to a notification that would have been delivered during quiet hours — is it dropped, or queued? How do we handle the migration of existing users' (implicit) preferences? These are not blockers, but they are things we should think about.
