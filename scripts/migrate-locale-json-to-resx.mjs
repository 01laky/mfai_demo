#!/usr/bin/env node
/**
 * One-time / repeatable: flatten nested i18n JSON → .NET .resx (en default, sk, cs for API "cz").
 * Run from monorepo root: node scripts/migrate-locale-json-to-resx.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

const LANG_FILE = { en: '', sk: '.sk', cz: '.cs' };

function flatten(obj, prefix = '') {
  const out = {};
  for (const [k, v] of Object.entries(obj)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v !== null && typeof v === 'object' && !Array.isArray(v)) {
      Object.assign(out, flatten(v, key));
    } else {
      out[key] = String(v ?? '');
    }
  }
  return out;
}

function escapeXml(s) {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function writeResx(targetPath, entries) {
  const sorted = Object.keys(entries).sort();
  const rows = sorted
    .map(
      (name) =>
        `  <data name="${escapeXml(name)}" xml:space="preserve">\n    <value>${escapeXml(entries[name])}</value>\n  </data>`
    )
    .join('\n');
  const xml = `<?xml version="1.0" encoding="utf-8"?>
<root>
  <xsd:schema id="root" xmlns="" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:msdata="urn:schemas-microsoft-com:xml-msdata">
    <xsd:import namespace="http://www.w3.org/XML/1998/namespace" />
    <xsd:element name="root" msdata:IsDataSet="true">
      <xsd:complexType>
        <xsd:choice maxOccurs="unbounded">
          <xsd:element name="metadata">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="value" type="xsd:string" minOccurs="0" />
              </xsd:sequence>
              <xsd:attribute name="name" use="required" type="xsd:string" />
              <xsd:attribute name="type" type="xsd:string" />
              <xsd:attribute name="mimetype" type="xsd:string" />
              <xsd:attribute ref="xml:space" />
            </xsd:complexType>
          </xsd:element>
          <xsd:element name="assembly">
            <xsd:complexType>
              <xsd:attribute name="alias" type="xsd:string" />
              <xsd:attribute name="name" type="xsd:string" />
            </xsd:complexType>
          </xsd:element>
          <xsd:element name="data">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="value" type="xsd:string" minOccurs="0" msdata:Ordinal="1" />
                <xsd:element name="comment" type="xsd:string" minOccurs="0" msdata:Ordinal="2" />
              </xsd:sequence>
              <xsd:attribute name="name" type="xsd:string" use="required" msdata:Ordinal="1" />
              <xsd:attribute name="type" type="xsd:string" msdata:Ordinal="3" />
              <xsd:attribute name="mimetype" type="xsd:string" msdata:Ordinal="4" />
              <xsd:attribute ref="xml:space" />
            </xsd:complexType>
          </xsd:element>
          <xsd:element name="resheader">
            <xsd:complexType>
              <xsd:sequence>
                <xsd:element name="value" type="xsd:string" minOccurs="0" msdata:Ordinal="1" />
              </xsd:sequence>
              <xsd:attribute name="name" type="xsd:string" use="required" />
            </xsd:complexType>
          </xsd:element>
        </xsd:choice>
      </xsd:complexType>
    </xsd:element>
  </xsd:schema>
  <resheader name="resmimetype">
    <value>text/microsoft-resx</value>
  </resheader>
  <resheader name="version">
    <value>2.0</value>
  </resheader>
  <resheader name="reader">
    <value>System.Resources.ResXResourceReader, System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089</value>
  </resheader>
  <resheader name="writer">
    <value>System.Resources.ResXResourceWriter, System.Windows.Forms, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089</value>
  </resheader>
${rows}
</root>
`;
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.writeFileSync(targetPath, xml, 'utf8');
}

function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

function migratePortalAdmin(app, resourceName, localeDir) {
  const outDir = path.join(root, 'many_faces_backend/BeDemo.Api/Localization', app);
  for (const [lang, suffix] of Object.entries(LANG_FILE)) {
    const file = path.join(localeDir, `${lang}.json`);
    if (!fs.existsSync(file)) {
      console.warn(`skip missing ${file}`);
      continue;
    }
    const flat = flatten(readJson(file));
    const fileName = `${resourceName}${suffix}.resx`;
    writeResx(path.join(outDir, fileName), flat);
    console.log(`wrote ${app}/${fileName} (${Object.keys(flat).length} keys)`);
  }
}

function migrateMobile() {
  const outDir = path.join(root, 'many_faces_backend/BeDemo.Api/Localization/Mobile');
  const enDir = path.join(root, 'many_faces_mobile/src/i18n/locales/en');
  const namespaces = ['common', 'login', 'register'];

  for (const [lang, suffix] of Object.entries(LANG_FILE)) {
    const merged = {};
    for (const ns of namespaces) {
      const file =
        lang === 'en'
          ? path.join(enDir, `${ns}.json`)
          : path.join(root, `many_faces_mobile/src/i18n/locales/${lang}/${ns}.json`);
      const src = fs.existsSync(file) ? readJson(file) : readJson(path.join(enDir, `${ns}.json`));
      const flat = flatten(src);
      for (const [k, v] of Object.entries(flat)) {
        merged[`${ns}.${k}`] = v;
      }
    }
    writeResx(path.join(outDir, `MobileResources${suffix}.resx`), merged);
    console.log(`wrote Mobile/MobileResources${suffix}.resx (${Object.keys(merged).length} keys)`);
  }
}

migratePortalAdmin('Portal', 'PortalResources', path.join(root, 'many_faces_portal/src/i18n/locales'));
migratePortalAdmin('Admin', 'AdminResources', path.join(root, 'many_faces_admin/src/i18n/locales'));
migrateMobile();
console.log('done');
