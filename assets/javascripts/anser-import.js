const module = {};

function ansiToHtml(data) {
  return Anser.linkify(Anser.ansiToHtml(Anser.escapeForHtml(data), {use_classes: true}));
}
