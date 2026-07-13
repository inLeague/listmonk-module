# Listmonk Module

A ColdBox module for interacting with a [Listmonk](https://listmonk.app) email server. Provides a typed API client built on [Hyper](https://hyper.ortusbooks.com) covering transactional email, subscribers, lists, templates, and more.

## Requirements

- BoxLang 1.0.0+
- ColdBox 7.0.0+
- Hyper 8.0.0+

## Installation

```bash
box install listmonk-module
```

## Configuration

In your ColdBox `config/ColdBox.cfc`, add the module settings:

```cfscript
moduleSettings = {
    listmonkModule = {
        baseUrl   : "https://listmonk.example.com",
        apiToken  : "your-api-token-here",
        timeout   : 30,
        subscriberMode : "external",
        contentType   : "html"
    }
};
```

### Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `baseUrl` | `http://localhost:9002` | Listmonk server URL |
| `apiToken` | `""` | API authentication token (Settings > Security in Listmonk admin) |
| `timeout` | `30` | HTTP request timeout in seconds |
| `subscriberMode` | `"external"` | Default subscriber mode for transactional sends (`external`, `default`, `fallback`) |
| `contentType` | `"html"` | Default content type for transactional sends (`html` or `plain`) |

## Usage

### Inject the Client

```cfscript
component {
    property name="listmonk" inject="ListmonkClient@listmonkModule";

    function doSomething() {
        // Health check
        var health = variables.listmonk.healthCheck();

        // Send a transactional email
        var result = variables.listmonk.sendTransactional({
            subscriber_emails : ["parent@example.com"],
            template_id       : 1,
            data              : { subject: "Hello", body: "<h1>Hi</h1>" },
            content_type      : "html"
        });
    }
}
```

### Transactional Email

```cfscript
var result = listmonk.sendTransactional({
    subscriber_mode  : "external",
    subscriber_emails : ["user1@example.com", "user2@example.com"],
    template_id       : 1,
    data              : {
        subject : "Team Update",
        body    : "<h1>Game Tomorrow</h1><p>See you at 9am.</p>"
    },
    content_type : "html"
});

if ( result.isOk() ) {
    // Success — result.data() contains the response
}
```

### Subscribers

```cfscript
// List subscribers
var subs = listmonk.getSubscribers( { query: "example.com", page: 1, limit: 20 } );

// Create
var created = listmonk.createSubscriber({
    email     : "new@example.com",
    name      : "New Sub",
    status    : "enabled",
    lists     : [ { id: 1 } ]
});

// Update
listmonk.updateSubscriber( created.data().id, { name: "Updated Name" } );

// Delete
listmonk.deleteSubscriber( 42 );
```

### Lists

```cfscript
var lists = listmonk.getLists();
var list  = listmonk.getList( 1 );

var newList = listmonk.createList( { name: "Parents", type: "public" } );
listmonk.updateList( newList.data().id, { name: "Parents Updated" } );
listmonk.deleteList( newList.data().id );
```

### Templates

```cfscript
var templates = listmonk.getTemplates();
var template  = listmonk.getTemplate( 1 );
```

## Response Object

All methods return a `ListmonkResponse` with:

| Method | Description |
|--------|-------------|
| `isOk()` | `true` if HTTP status is 2xx |
| `isError()` | `true` if HTTP status is 4xx/5xx |
| `status()` | HTTP status code |
| `data()` | Parsed response body (`data` key from Listmonk) |
| `raw()` | Raw Hyper response object |
| `message()` | Error message from Listmonk, if any |

## License

MIT
