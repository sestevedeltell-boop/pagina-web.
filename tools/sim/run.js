// Ejecuta tools/sim/test.lua con el simulador. Uso: node tools/sim/run.js [--dump salida.tsv]
const fs = require("fs");
const path = require("path");
const fengari = require(process.env.FENGARI_PATH || "fengari");
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = fengari;

const root = path.join(__dirname, "..", "..");
const files = {};
(function walk(dir) {
  for (const f of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, f.name);
    if (f.isDirectory()) walk(p);
    else if (f.name.endsWith(".lua")) files[path.relative(root, p).split(path.sep).join("/")] = fs.readFileSync(p, "utf8");
  }
})(path.join(root, "src"));

const dumpIdx = process.argv.indexOf("--dump");
let code = "FILES = {\n";
for (const [k, v] of Object.entries(files)) code += `["${k}"] = [==[${v}]==],\n`;
code += "}\n";
if (dumpIdx > -1) code += "DUMP = true\n";
code += fs.readFileSync(path.join(__dirname, "stubs.lua"), "utf8") + "\n";
code += fs.readFileSync(path.join(__dirname, "test.lua"), "utf8");

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const out = [];
lua.lua_pushjsfunction(L, (L) => {
  const n = lua.lua_gettop(L);
  const parts = [];
  for (let i = 1; i <= n; i++) parts.push(to_jsstring(lauxlib.luaL_tolstring(L, i)));
  out.push(parts.join("\t"));
  return 0;
});
lua.lua_setglobal(L, to_luastring("print"));
const status = lauxlib.luaL_dostring(L, to_luastring(code));
const lines = out.join("\n");
if (dumpIdx > -1) {
  fs.writeFileSync(process.argv[dumpIdx + 1], out.filter((l) => l.startsWith("PART\t")).join("\n"));
  console.log(out.filter((l) => !l.startsWith("PART\t")).join("\n"));
} else console.log(lines);
if (status !== 0) {
  console.error("ERROR Lua:", to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(1);
}
