document.addEventListener("DOMContentLoaded", () => {
  const form = document.querySelector("form[data-intake-draft]");
  const errors = document.getElementById("intake-errors");
  if (errors) errors.focus();
  if (!form) return;
  let dirty = form.dataset.intakeUnsaved === "true";
  form.addEventListener("input", () => { dirty = true; });
  form.addEventListener("change", () => { dirty = true; });
  form.addEventListener("submit", () => { dirty = false; });
  window.addEventListener("beforeunload", (event) => {
    if (dirty) { event.preventDefault(); event.returnValue = ""; }
  });
});

document.addEventListener("DOMContentLoaded", () => {
  const type = document.getElementById("field_value_type");
  const widget = document.getElementById("field_widget");
  if (!type || !widget) return;
  const allowed = {text: ["text", "textarea", "email", "tel"], integer: ["number"], decimal: ["number"], boolean: ["boolean_radio", "checkbox"], date: ["date"], datetime: ["datetime"], single_choice: ["select", "radio"], multiple_choice: ["checkbox_group", "multi_select"], attachment: ["file"]};
  const update = () => {
    const values = allowed[type.value];
    for (const option of widget.options) { option.disabled = !values.includes(option.value); option.hidden = option.disabled; }
    if (!values.includes(widget.value)) widget.value = values[0];
  };
  type.addEventListener("change", update);
  update();
});
