## Keycloak-js

[back](./keycloak.md)

Integrating Keycloak with a React application primarily involves setting up the `keycloak-js` adapter. To handle API requests, you'll use Axios interceptors that automatically attach the current access token to outgoing requests and refresh it when necessary.

Here is a step-by-step guide to the complete setup and token handling process.

### 1. Installation

First, you need to install the required packages. You will need the Keycloak JavaScript adapter and React bindings to manage authentication state .

```bash
npm install keycloak-js @react-keycloak-fork/web
```

### 2. Configuration and Provider Setup

Create a file to initialize the Keycloak instance and wrap your React application with the provider.

**Step 2.1: Create Keycloak Instance (`src/keycloak.js`)**
This file configures the adapter with your Keycloak server details .

```javascript
import Keycloak from "keycloak-js";

const keycloakConfig = {
  url: "http://localhost:8080", // Your Keycloak server URL
  realm: "your-realm", // Your realm name
  clientId: "your-client-id", // Your public client ID
};

const keycloak = new Keycloak(keycloakConfig);
export default keycloak;
```

**Step 2.2: Wrap App with Provider (`src/index.js` or `App.js`)**
The `ReactKeycloakProvider` initializes Keycloak and manages authentication state for your app. The `onTokens` prop is crucial for capturing tokens when they are refreshed or updated .

```jsx
import React from "react";
import ReactDOM from "react-dom/client";
import { ReactKeycloakProvider } from "@react-keycloak-fork/web";
import App from "./App";
import keycloak from "./keycloak";

// Event handler to listen to Keycloak events (optional but helpful for debugging)
const keycloakProviderEvents = {
  onEvent: (event, error) => {
    console.log("Keycloak Event:", event, error);
  },
  onTokens: (tokens) => {
    console.log("Tokens refreshed/updated", tokens);
    // You can store tokens in localStorage here if needed for the interceptor
    // localStorage.setItem('auth_token', tokens.token);
  },
};

const root = ReactDOM.createRoot(document.getElementById("root"));
root.render(
  <ReactKeycloakProvider
    authClient={keycloak}
    initOptions={{ onLoad: "login-required" }} // Force login if not authenticated
    onEvent={keycloakProviderEvents.onEvent}
    onTokens={keycloakProviderEvents.onTokens}
  >
    <App />
  </ReactKeycloakProvider>,
);
```

### 3. Token Handling in Axios Interceptor

This is the core part where you ensure every HTTP request has a valid token. The interceptor will check if the token is about to expire, refresh it if necessary, and then attach it to the request headers .

**Create an Axios instance with interceptors (`src/services/api.js`)**

```javascript
import axios from "axios";
import keycloak from "../keycloak"; // Import the instance directly

// Function to get the latest token
// If you stored tokens in localStorage in the onTokens callback, retrieve them here.
// Otherwise, fetch directly from the keycloak instance.
const getToken = () => {
  return keycloak.token;
};

// Create axios instance
const api = axios.create({
  baseURL: "http://localhost:8081/api", // Your backend API URL
});

// Request Interceptor
api.interceptors.request.use(
  async (config) => {
    // Check if token exists and is not expired (with a 10-second buffer)
    if (keycloak.authenticated && keycloak.isTokenExpired(10)) {
      console.log("Token expired or about to expire. Refreshing...");
      try {
        // Attempt to refresh the token
        const refreshed = await keycloak.updateToken(10);
        if (refreshed) {
          console.log("Token refreshed successfully");
        } else {
          console.log("Token still valid, no refresh needed");
        }
      } catch (error) {
        console.error("Failed to refresh token", error);
        // If refresh fails, redirect to login
        keycloak.login();
        return Promise.reject(error);
      }
    }

    // Attach the token to the Authorization header
    const token = getToken();
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => {
    return Promise.reject(error);
  },
);

export default api;
```

**Alternative: Direct Promise-based approach**
If you prefer not using `async/await`, you can structure the token check using promises, which is closer to how the Keycloak `updateToken` method was traditionally used .

```javascript
api.interceptors.request.use((config) => {
  return new Promise((resolve, reject) => {
    if (keycloak.authenticated && keycloak.isTokenExpired(10)) {
      keycloak
        .updateToken(10)
        .success((refreshed) => {
          if (refreshed) console.log("Token refreshed");
          config.headers.Authorization = `Bearer ${keycloak.token}`;
          resolve(config);
        })
        .error(() => {
          console.error("Failed to refresh token");
          keycloak.login();
          reject("Token refresh failed");
        });
    } else {
      if (keycloak.token) {
        config.headers.Authorization = `Bearer ${keycloak.token}`;
      }
      resolve(config);
    }
  });
});
```

### 4. Using the Authenticated API in Components

Now you can use the `useKeycloak` hook to check authentication status and the configured `api` instance to make requests .

```jsx
import React, { useEffect, useState } from "react";
import { useKeycloak } from "@react-keycloak-fork/web";
import api from "./services/api"; // Your configured axios instance

const Dashboard = () => {
  const { keycloak, initialized } = useKeycloak();
  const [data, setData] = useState(null);

  useEffect(() => {
    const fetchData = async () => {
      if (initialized && keycloak.authenticated) {
        try {
          // The token is automatically attached by the interceptor
          const response = await api.get("/protected-resource");
          setData(response.data);
        } catch (error) {
          console.error("API call failed", error);
        }
      }
    };
    fetchData();
  }, [initialized, keycloak.authenticated]);

  if (!initialized) {
    return <div>Loading Keycloak...</div>;
  }

  return (
    <div>
      {keycloak.authenticated ? (
        <div>
          <p>Welcome, {keycloak.tokenParsed?.preferred_username}</p>
          <pre>{JSON.stringify(data, null, 2)}</pre>
          <button onClick={() => keycloak.logout()}>Logout</button>
        </div>
      ) : (
        <button onClick={() => keycloak.login()}>Login</button>
      )}
    </div>
  );
};

export default Dashboard;
```

### Summary

| Step  | Component                      | Purpose                                                                                                  |
| :---- | :----------------------------- | :------------------------------------------------------------------------------------------------------- |
| **1** | `keycloak-js` & React Bindings | Provide authentication logic and React context.                                                          |
| **2** | `ReactKeycloakProvider`        | Initializes Keycloak and manages global auth state.                                                      |
| **3** | Axios Interceptor              | Proactively checks token expiry, refreshes if needed, and attaches the `Bearer` token to every request . |
| **4** | `useKeycloak` Hook             | Allows components to access login/logout functions and user info.                                        |

This design ensures that your React application handles token expiration automatically and securely attaches credentials to all outgoing API requests without requiring manual token management in each component.

---

Here are the most common and useful Keycloak functions you'll use in your React application:

## Core Keycloak Instance Methods

These methods are available on the `keycloak` object returned by `useKeycloak()` or your initialized instance:

### 1. **Authentication & Session Management**

```javascript
const { keycloak } = useKeycloak();

// Login - redirects to Keycloak login page
keycloak.login();
// With options
keycloak.login({
  redirectUri: window.location.origin + "/dashboard",
  locale: "en",
  idpHint: "google", // Force specific identity provider
});

// Logout - ends session and redirects
keycloak.logout();
// With options
keycloak.logout({
  redirectUri: window.location.origin,
});

// Register new user
keycloak.register();
// With options
keycloak.register({
  redirectUri: window.location.origin + "/welcome",
});

// Check if user is authenticated
const isAuth = keycloak.authenticated; // boolean

// Get authentication token
const token = keycloak.token;
const parsedToken = keycloak.tokenParsed; // Decoded JWT

// Get refresh token
const refreshToken = keycloak.refreshToken;
```

### 2. **Token Management**

```javascript
// Check if token is expired
const expired = keycloak.isTokenExpired();
// With buffer (seconds) - token considered expired if it will expire in X seconds
const willExpireSoon = keycloak.isTokenExpired(30); // 30 seconds buffer

// Refresh token manually
try {
  const refreshed = await keycloak.updateToken(30); // 30 seconds buffer
  if (refreshed) {
    console.log("Token refreshed successfully");
    // Get new token
    const newToken = keycloak.token;
  }
} catch (error) {
  console.error("Token refresh failed", error);
  keycloak.login(); // Redirect to login
}

// Get remaining token lifetime in seconds
const tokenRemaining = keycloak.tokenRemaining; // property (not a function)
```

### 3. **User Information**

```javascript
// Get user profile from Keycloak
try {
  const profile = await keycloak.loadUserProfile();
  console.log({
    id: profile.id,
    username: profile.username,
    email: profile.email,
    firstName: profile.firstName,
    lastName: profile.lastName,
    attributes: profile.attributes,
  });
} catch (error) {
  console.error("Failed to load user profile", error);
}

// Access token claims directly (parsed token)
const userId = keycloak.tokenParsed?.sub;
const username = keycloak.tokenParsed?.preferred_username;
const email = keycloak.tokenParsed?.email;
const roles = keycloak.tokenParsed?.realm_access?.roles || [];
```

### 4. **Role & Permission Checking**

```javascript
// Check realm roles
const hasAdminRole = keycloak.hasRealmRole("admin");
const hasUserRole = keycloak.hasRealmRole("user");

// Check client roles (specific to this client)
const hasManageAccess = keycloak.hasResourceRole("manage", "your-client-id");

// More flexible role checking
const checkUserRole = () => {
  const roles = keycloak.tokenParsed?.realm_access?.roles || [];
  return roles.includes("admin") || roles.includes("moderator");
};

// Check resource permissions
const canAccessResource = async (resource, scope) => {
  try {
    const result = await keycloak.hasResourceRole(resource, scope);
    return result;
  } catch (error) {
    return false;
  }
};
```

### 5. **Account Management**

```javascript
// Open Keycloak account management page
keycloak.accountManagement();

// Get account URL manually
const accountUrl = keycloak.createAccountUrl({
  redirectUri: window.location.href,
});
```

## React Keycloak Provider Events

These are useful for global app behavior:

```javascript
<ReactKeycloakProvider
    authClient={keycloak}
    onEvent={(event, error) => {
        switch (event) {
            case 'onAuthSuccess':
                console.log('User authenticated successfully');
                // Track analytics, set up app state
                break;
            case 'onAuthRefreshSuccess':
                console.log('Token refreshed');
                // Update any stored tokens
                break;
            case 'onAuthLogout':
                console.log('User logged out');
                // Clear app state, redirect to home
                break;
            case 'onTokenExpired':
                console.log('Token has expired');
                // App will handle refresh automatically
                break;
            case 'onAuthError':
                console.error('Authentication error:', error);
                break;
        }
    }}
    onTokens={(tokens) => {
        // Save tokens for interceptor or offline usage
        localStorage.setItem('keycloak_token', tokens.token);
        localStorage.setItem('keycloak_refresh_token', tokens.refreshToken);
    }}
>
```

## Complete Utility Functions Example

Here's a custom hook that wraps common Keycloak operations:

```javascript
// hooks/useKeycloakWrapper.js
import { useKeycloak } from "@react-keycloak-fork/web";
import { useCallback } from "react";

export const useKeycloakWrapper = () => {
  const { keycloak, initialized } = useKeycloak();

  const logout = useCallback(async () => {
    try {
      // Clear local data first
      localStorage.removeItem("keycloak_token");
      localStorage.removeItem("user_preferences");

      // Perform Keycloak logout
      await keycloak.logout({
        redirectUri: window.location.origin,
      });
    } catch (error) {
      console.error("Logout failed", error);
      // Force logout locally if Keycloak fails
      window.location.href = "/";
    }
  }, [keycloak]);

  const getValidToken = useCallback(async () => {
    if (!keycloak.authenticated) {
      return null;
    }

    try {
      // Check if token is expired or will expire in 30 seconds
      if (keycloak.isTokenExpired(30)) {
        await keycloak.updateToken(30);
      }
      return keycloak.token;
    } catch (error) {
      console.error("Failed to get valid token", error);
      keycloak.login();
      return null;
    }
  }, [keycloak]);

  const hasAnyRole = useCallback(
    (requiredRoles) => {
      if (!keycloak.authenticated || !keycloak.tokenParsed) {
        return false;
      }

      const userRoles = keycloak.tokenParsed.realm_access?.roles || [];
      return requiredRoles.some((role) => userRoles.includes(role));
    },
    [keycloak],
  );

  const getUserInfo = useCallback(async () => {
    if (!keycloak.authenticated) return null;

    try {
      const profile = await keycloak.loadUserProfile();
      return {
        username: profile.username,
        email: profile.email,
        firstName: profile.firstName,
        lastName: profile.lastName,
        roles: keycloak.tokenParsed?.realm_access?.roles || [],
      };
    } catch (error) {
      console.error("Failed to get user info", error);
      return null;
    }
  }, [keycloak]);

  return {
    initialized,
    authenticated: keycloak.authenticated,
    tokenParsed: keycloak.tokenParsed,
    login: keycloak.login,
    logout,
    register: keycloak.register,
    getValidToken,
    hasAnyRole,
    getUserInfo,
    accountManagement: keycloak.accountManagement,
    refreshToken: () => keycloak.updateToken(30),
  };
};
```

## Usage Example in Components

```javascript
// UserProfile.jsx
import { useKeycloakWrapper } from "../hooks/useKeycloakWrapper";

const UserProfile = () => {
  const { initialized, authenticated, getUserInfo, logout, hasAnyRole } =
    useKeycloakWrapper();

  const [userInfo, setUserInfo] = useState(null);

  useEffect(() => {
    if (authenticated) {
      getUserInfo().then(setUserInfo);
    }
  }, [authenticated, getUserInfo]);

  if (!initialized) return <div>Loading...</div>;
  if (!authenticated)
    return <button onClick={() => keycloak.login()}>Login</button>;

  return (
    <div>
      <h2>
        Welcome, {userInfo?.firstName} {userInfo?.lastName}
      </h2>
      <p>Email: {userInfo?.email}</p>
      <p>Username: {userInfo?.username}</p>

      {hasAnyRole(["admin", "moderator"]) && <button>Admin Panel</button>}

      <button onClick={logout}>Logout</button>
    </div>
  );
};
```

## Key Points Summary

| Method                | Purpose                    | Common Use Case      |
| --------------------- | -------------------------- | -------------------- |
| `login()`             | Redirect to Keycloak login | Authentication start |
| `logout()`            | End session                | User sign out        |
| `register()`          | New user registration      | Sign-up flow         |
| `isTokenExpired()`    | Check token validity       | Before API calls     |
| `updateToken()`       | Refresh token              | Keep session alive   |
| `loadUserProfile()`   | Get user details           | Display user info    |
| `hasRealmRole()`      | Check authorization        | Feature gating       |
| `accountManagement()` | Manage account             | Profile settings     |

These functions give you complete control over authentication flow, session management, and user information in your React application.
