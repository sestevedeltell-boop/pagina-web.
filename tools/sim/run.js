// Ejecuta las pruebas del simulador.
//   node tools/sim/run.js [--solo Mapa] [--only prueba] [--dump salida.tsv] [--client]
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

const arg = (name) => { const i = process.argv.indexOf(name); return i > -1 ? process.argv[i + 1] : null; };
const longStr = (s) => { let n = 0; while (s.includes("]" + "=".repeat(n) + "]")) n++; return "[" + "=".repeat(n) + "[" + s + "]" + "=".repeat(n) + "]"; };

let code = "FILES = {\n";
for (const [k, v] of Object.entries(files)) code += `["${k}"] = ${longStr(v)},\n`;
code += "}\n";
if (arg("--solo")) code += `SOLO = ${JSON.stringify(arg("--solo"))}\n`;
if (arg("--only")) code += `ONLY = ${JSON.stringify(arg("--only"))}\n`;
if (process.argv.includes("--dump")) code += "DUMP = true\n";
code += fs.readFileSync(path.join(__dirname, "stubs.lua"), "utf8") + "\n";
const extraFile = path.join(__dirname, process.argv.includes("--client") ? "client_test.lua" : "test_extra.lua");
if (fs.existsSync(extraFile)) code += `TEST_EXTRA = ${longStr(fs.readFileSync(extraFile, "utf8"))}\n`;
code += fs.readFileSync(path.join(__dirname, process.argv.includes("--client") ? "client_main.lua" : "test.lua"), "utf8");

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
const out = [];
lua.lua_pushjsfunction(L, (L) => {
  const n = lua.lua_gettop(L);
  const parts = [];
  for (let i = 1; i <= n; i++) parts.push(to_jsstring(lauxlib.luaL_tolstring(L, i)));
  const line = parts.join("\t");
  if (line.startsWith("PART\t")) out.push(line); else console.log(line);
  return 0;
});
lua.lua_setglobal(L, to_luastring("print"));
const status = lauxlib.luaL_dostring(L, to_luastring(code));
if (arg("--dump")) fs.writeFileSync(arg("--dump"), out.join("\n"));
if (status !== 0) {
  console.error("ERROR Lua:", to_jsstring(lua.lua_tostring(L, -1)));
  process.exit(1);
}
