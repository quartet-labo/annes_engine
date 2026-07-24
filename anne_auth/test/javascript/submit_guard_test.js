const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const partialPath = path.join(
  __dirname,
  "../../app/views/layouts/anne_auth/_submit_guard.html.erb"
);
const partial = fs.readFileSync(partialPath, "utf8");
const script = partial.match(/<script[^\n]*\n([\s\S]*?)<\/script>/)[1];

class EventTarget {
  constructor() {
    this.listeners = new Map();
  }

  addEventListener(type, listener) {
    const listeners = this.listeners.get(type) || [];
    listeners.push(listener);
    this.listeners.set(type, listeners);
  }

  dispatchEvent(event) {
    for (const listener of this.listeners.get(event.type) || []) {
      listener(event);
    }
    return !event.defaultPrevented;
  }
}

class Control {
  constructor({ disabled = false, name = "", value = "" } = {}) {
    this.attributes = new Map();
    this.disabled = disabled;
    this.name = name;
    this.value = value;
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null;
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }

  removeAttribute(name) {
    this.attributes.delete(name);
  }
}

class Form {
  constructor({ guarded = true, controls = [] } = {}) {
    this.nodeName = "FORM";
    this.attributes = new Map();
    this.controls = controls;
    if (guarded) this.setAttribute("data-anne-auth-submit-guard", "true");
  }

  getAttribute(name) {
    return this.attributes.has(name) ? this.attributes.get(name) : null;
  }

  hasAttribute(name) {
    return this.attributes.has(name);
  }

  matches(selector) {
    return selector === "[data-anne-auth-submit-guard]" &&
      this.hasAttribute("data-anne-auth-submit-guard");
  }

  querySelectorAll() {
    return this.controls;
  }

  setAttribute(name, value) {
    this.attributes.set(name, String(value));
  }

  removeAttribute(name) {
    this.attributes.delete(name);
  }
}

function createEvent(type, target) {
  return {
    type,
    target,
    defaultPrevented: false,
    preventDefault() {
      this.defaultPrevented = true;
    }
  };
}

function setup() {
  const document = new EventTarget();
  const window = new EventTarget();
  const timers = [];
  window.window = window;

  const context = vm.createContext({
    document,
    window,
    setTimeout(callback) {
      timers.push(callback);
    }
  });

  const install = () => vm.runInContext(script, context);
  const runTimers = () => {
    while (timers.length > 0) timers.shift()();
  };

  install();
  return { document, install, runTimers, window };
}

test("allows the first submit and disables controls after event processing", () => {
  const { document, runTimers } = setup();
  const submitter = new Control({ name: "commit", value: "ログイン" });
  const form = new Form({ controls: [submitter] });
  const event = createEvent("submit", form);

  assert.equal(document.dispatchEvent(event), true);
  assert.equal(submitter.disabled, false);
  assert.equal(submitter.name, "commit");
  assert.equal(submitter.value, "ログイン");
  assert.equal(form.getAttribute("aria-busy"), "true");

  runTimers();

  assert.equal(submitter.disabled, true);
  assert.equal(
    submitter.getAttribute("data-anne-auth-submit-guard-disabled"),
    "true"
  );
});

test("prevents a second submit while the form is locked", () => {
  const { document } = setup();
  const form = new Form({ controls: [new Control()] });

  assert.equal(document.dispatchEvent(createEvent("submit", form)), true);
  assert.equal(document.dispatchEvent(createEvent("submit", form)), false);
});

test("ignores forms without opt-in and already-cancelled submits", () => {
  const { document, runTimers } = setup();
  const plainControl = new Control();
  const plainForm = new Form({ guarded: false, controls: [plainControl] });
  const cancelledControl = new Control();
  const cancelledForm = new Form({ controls: [cancelledControl] });
  const cancelledEvent = createEvent("submit", cancelledForm);
  cancelledEvent.preventDefault();

  document.dispatchEvent(createEvent("submit", plainForm));
  document.dispatchEvent(cancelledEvent);
  runTimers();

  assert.equal(plainControl.disabled, false);
  assert.equal(plainForm.getAttribute("aria-busy"), null);
  assert.equal(cancelledControl.disabled, false);
  assert.equal(cancelledForm.getAttribute("aria-busy"), null);
});

test("unlocks a submit cancelled by a later event listener", () => {
  const { document, runTimers } = setup();
  const control = new Control();
  const form = new Form({ controls: [control] });
  document.addEventListener("submit", (event) => event.preventDefault());

  assert.equal(document.dispatchEvent(createEvent("submit", form)), false);
  runTimers();

  assert.equal(control.disabled, false);
  assert.equal(form.getAttribute("aria-busy"), null);
  assert.equal(
    form.getAttribute("data-anne-auth-submit-guard-locked"),
    null
  );
});

test("pageshow resets only state changed by the guard", () => {
  const { document, runTimers, window } = setup();
  const enabledControl = new Control();
  const initiallyDisabledControl = new Control({ disabled: true });
  const form = new Form({
    controls: [enabledControl, initiallyDisabledControl]
  });
  form.setAttribute("aria-busy", "polite");

  document.dispatchEvent(createEvent("submit", form));
  runTimers();
  window.dispatchEvent(createEvent("pageshow", window));

  assert.equal(enabledControl.disabled, false);
  assert.equal(initiallyDisabledControl.disabled, true);
  assert.equal(form.getAttribute("aria-busy"), "polite");
});

test("turbo submit end unlocks the submitted form", () => {
  const { document, runTimers } = setup();
  const control = new Control();
  const form = new Form({ controls: [control] });

  document.dispatchEvent(createEvent("submit", form));
  runTimers();
  document.dispatchEvent(createEvent("turbo:submit-end", form));

  assert.equal(control.disabled, false);
  assert.equal(form.getAttribute("aria-busy"), null);
});

test("installing the script more than once does not duplicate listeners", () => {
  const { document, install, window } = setup();
  const submitListenerCount = document.listeners.get("submit").length;
  const turboListenerCount =
    document.listeners.get("turbo:submit-end").length;
  const pageshowListenerCount = window.listeners.get("pageshow").length;

  install();

  assert.equal(document.listeners.get("submit").length, submitListenerCount);
  assert.equal(
    document.listeners.get("turbo:submit-end").length,
    turboListenerCount
  );
  assert.equal(
    window.listeners.get("pageshow").length,
    pageshowListenerCount
  );
});
