# Data Dictionary

This dictionary reflects the table definitions in `setup/00_create_tables.sql`.

## `users`

| Column | Type | Description |
| --- | --- | --- |
| `user_id` | VARCHAR | Unique identifier for a user. |
| `signup_time` | TIMESTAMP | Date and time the user signed up. |
| `country` | VARCHAR | User's country. |

## `events`

| Column | Type | Description |
| --- | --- | --- |
| `event_id` | VARCHAR | Unique identifier for an event. |
| `user_id` | VARCHAR | Identifier of the user who performed the event. |
| `event_time` | TIMESTAMP | Date and time the event occurred. |
| `event_name` | VARCHAR | Name of the event, such as `checkout_complete`. |
| `feature_name` | VARCHAR | Optional product feature associated with the event. |
| `session_id` | VARCHAR | Identifier for the user session. |
| `duration_ms` | INTEGER | Event or feature duration in milliseconds. |

## `subscriptions`

| Column | Type | Description |
| --- | --- | --- |
| `subscription_id` | VARCHAR | Unique identifier for a subscription. |
| `user_id` | VARCHAR | Identifier of the subscribed user. |
| `start_date` | DATE | Subscription start date. |
| `end_date` | DATE | Subscription end date. |
| `plan` | VARCHAR | Subscription plan. |
| `mrr_amount` | DECIMAL | Monthly recurring revenue amount. |

## `conversions`

| Column | Type | Description |
| --- | --- | --- |
| `conversion_id` | VARCHAR | Unique identifier for a conversion. |
| `user_id` | VARCHAR | Identifier of the converted user. |
| `conversion_time` | TIMESTAMP | Date and time of conversion. |
| `conversion_type` | VARCHAR | Type of conversion recorded. |

## `nps_responses`

| Column | Type | Description |
| --- | --- | --- |
| `response_id` | VARCHAR | Unique identifier for an NPS response. |
| `user_id` | VARCHAR | Identifier of the responding user. |
| `response_date` | DATE | Date the NPS response was submitted. |
| `score` | INTEGER | NPS score submitted by the user. |
| `feedback` | TEXT | Free-text feedback from the user. |

## `acquisition_costs`

| Column | Type | Description |
| --- | --- | --- |
| `user_id` | VARCHAR | Identifier of the acquired user. |
| `acquisition_channel` | VARCHAR | Channel through which the user was acquired. |
| `cost` | DECIMAL | Acquisition cost attributed to the user. |
