### Core JSF Tags (xmlns:jsf)

- jsf:id: Assigns a client ID to a non-JSF HTML tag, making it a JSF component.

- jsf:value: Adds a value expression to a non-JSF HTML tag.

- jsf:action: Adds an action expression to a non-JSF HTML tag (e.g., on a button).

### Facelets Tags (xmlns:ui)

- ui:composition: Defines a template, ignoring everything outside the tag.

- ui:define: Defines content that replaces a placeholder in a template.

- ui:insert: Creates a placeholder in a template for content to be inserted.

- ui:decorate

- ui:include: Includes the content of another XHTML file.

- ui:repeat: A basic iterator for looping, unlike h:dataTable.

- ui:fragment: Similar to ui:composition but does not ignore outer content.

- ui:param: Passes parameters to an included file or a template component.

- ui:debug: Provides a debug popup with component tree and scoped variables.

- ui:remove: Removes content from the rendered page.

### HTML Tags (xmlns:h)

- h:head: Renders the HTML head element.

- h:body: Renders the HTML body element.

- h:outputStylesheet: Declares a CSS stylesheet.

- h:outputScript: Declares a JavaScript file.

- h:form: Renders an HTML form.

- h:inputText: Renders a text input field.

- h:inputSecret: Renders a password input field.

- h:selectOneMenu: Renders a dropdown list (single selection).

- h:selectManyMenu: Renders a listbox (multiple selection).

- h:selectOneRadio: Renders a group of radio buttons.

- h:selectOneCheckbox: Renders a single checkbox.

- h:selectManyCheckbox: Renders a group of checkboxes.

- h:outputLabel: Renders a label for an input field.

- h:outputLink: Renders an HTML anchor tag (for GET navigation).

- h:commandButton: Renders a button that submits the form (POST).

- h:commandLink: Renders a link that submits the form (POST).

- h:outputText: Renders text, often used with value expressions.

- h:dataTable: Renders an HTML table from a collection of data.

- h:panelGrid: Renders an HTML table structure based on columns.

- h:panelGroup: Groups components together to act as a single entity.

- h:message: Displays a message for a specific component.

- h:messages: Displays all messages for the entire page.

- h:graphicImage: Renders an image.

### Core Tags (xmlns:f)

- f:ajax: Adds AJAX functionality to a component.

- f:actionListener: Adds an action listener to a component.

- f:attribute: Adds an attribute to a component (set before rendering).

- f:param: Adds a parameter to a component (e.g., for a link or output).

- f:setPropertyActionListener: A specific listener to set a value during form submit.

- f:validator: Attaches a validator to an input component.

- f:validateBean: Enables bean validation (JSR 303).

- f:validateLength: Validates the length of input.

- f:validateDoubleRange: Validates a numeric range for doubles.

- f:validateLongRange: Validates a numeric range for longs.

- f:validateRegex: Validates input against a regular expression.

- f:validateRequired: Ensures a field is not empty.

- f:viewParam: Declares a query parameter for the view (for GET requests).

- f:viewAction: Executes an action when the view is loaded.

- f:convertDateTime: Converts a String to/from a Date object.

- f:convertNumber: Converts a String to/from a Number object.

- f:loadBundle: Loads a resource bundle for internationalization.

- f:selectItem: Defines a single item for a selection component.

- f:selectItems: Defines a list of items for a selection component.

- f:metadata: Container for f:viewParam and f:viewAction tags.
