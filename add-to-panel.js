var panel = panels().filter(function (p) { return p.location === "top"; })[0];
if (panel.widgets("io.github.aethryl.soundbar").length === 0) {
    panel.currentConfigGroup = ["General"];
    var order = String(panel.readConfig("AppletOrder", "")).split(";").filter(function (id) { return id !== ""; });
    var added = panel.addWidget("io.github.aethryl.soundbar");
    order = order.filter(function (id) { return id !== String(added.id); });
    var mural = panel.widgets("io.github.aethryl.mural")[0];
    var at = mural ? order.indexOf(String(mural.id)) : order.length;
    order.splice(at, 0, String(added.id));
    panel.currentConfigGroup = ["General"];
    panel.writeConfig("AppletOrder", order.join(";"));
}
