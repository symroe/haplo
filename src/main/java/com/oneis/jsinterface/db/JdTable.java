/* Haplo Platform                                     http://haplo.org
 * (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */

package com.oneis.jsinterface.db;

import com.oneis.javascript.Runtime;
import com.oneis.javascript.OAPIException;
import com.oneis.javascript.JsGet;
import com.oneis.jsinterface.KScriptable;
import org.mozilla.javascript.*;

import java.util.HashSet;
import java.util.ArrayList;
import java.util.Date;

import java.sql.Connection;
import java.sql.Statement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

// JS host objects for field types
import com.oneis.jsinterface.KObjRef;
import com.oneis.jsinterface.KUser;
import com.oneis.jsinterface.KStoredFile;

// TODO: Handle java.sql.SQLException exceptions? Or use a global method of turning exceptions into something presentable to the JS code?
public class JdTable extends KScriptable {
    private String dbName;
    private String jsName;
    private Function factory;
    private Field[] fields;
    private JdNamespace namespace;
    private String databaseTableName;

    public JdTable() {
    }

    public String getClassName() {
        return "$DbTable";
    }

    public void setNamespace(JdNamespace namespace) {
        this.namespace = namespace;
    }

    public JdNamespace getNamespace() {
        return this.namespace;
    }

    // --------------------------------------------------------------------------------------------------------------
    private String getDatabaseTableName() {
        if(databaseTableName == null) {
            if(this.dbName == null || this.namespace == null) {
                throw new RuntimeException("JdTable not set up correctly");
            }
            databaseTableName = ("j_" + this.namespace.getName() + "_" + this.dbName).toLowerCase();
        }
        return databaseTableName;
    }

    protected Field getField(String fieldName) {
        for(Field field : fields) {
            if(field.getJsName().equals(fieldName)) {
                return field;
            }
        }
        return null;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void jsConstructor(String name, Scriptable fields, Scriptable methods) {
        Runtime runtime = Runtime.getCurrentRuntime();

        JdNamespace.checkNameIsAllowed(name);
        this.put("tableName", this, name);
        this.dbName = name.toLowerCase();
        this.jsName = name;

        // Run through the fields, creating the field objects
        ArrayList<Field> fieldList = new ArrayList<Field>(20);
        HashSet<String> nameChecks = new HashSet<String>();
        Object[] fieldNames = fields.getIds();
        int linkAliasNumber = 0;    // used for generating the alias names for linked fields, used in queries
        for(Object fieldId : fieldNames) {
            if(fieldId instanceof String) // ConsString is checked
            {
                String fieldName = (String)fieldId; // ConsString is checked
                // Check name is allowed and doesn't duplicate any other name
                JdNamespace.checkNameIsAllowed(fieldName);
                String fieldNameLower = fieldName.toLowerCase();
                if(nameChecks.contains(fieldNameLower)) {
                    throw new OAPIException("Field name " + name + "." + fieldName + " differs from another field name by case only.");
                }
                nameChecks.add(fieldNameLower);
                if(fieldNameLower.equals("id")) {
                    throw new OAPIException("'id' is not allowed as field name.");
                }

                // Extract field definition
                Scriptable defn = JsGet.scriptable(fieldName, fields);
                if(defn == null) {
                    throw new OAPIException("Bad field definition " + name + "." + fieldName);
                }
                String fieldType = JsGet.string("type", defn);
                if(fieldType == null) {
                    throw new OAPIException("Bad type in field definition for " + name + "." + fieldName);
                }
                // Create the field object
                Field field = null;
                if(fieldType.equals("text")) {
                    field = new TextField(fieldName, defn);
                } else if(fieldType.equals("datetime")) {
                    field = new DateTimeField(fieldName, defn);
                } else if(fieldType.equals("date")) {
                    field = new DateField(fieldName, defn);
                } else if(fieldType.equals("time")) {
                    field = new TimeField(fieldName, defn);
                } else if(fieldType.equals("boolean")) {
                    field = new BooleanField(fieldName, defn);
                } else if(fieldType.equals("smallint")) {
                    field = new SmallIntField(fieldName, defn);
                } else if(fieldType.equals("int")) {
                    field = new IntField(fieldName, defn);
                } else if(fieldType.equals("bigint")) {
                    field = new BigIntField(fieldName, defn);
                } else if(fieldType.equals("float")) {
                    field = new FloatField(fieldName, defn);
                } else if(fieldType.equals("ref")) {
                    field = new ObjRefField(fieldName, defn);
                } else if(fieldType.equals("file")) {
                    field = new FileField(fieldName, defn);
                } else if(fieldType.equals("link")) {
                    field = new LinkField(fieldName, defn, "i" + linkAliasNumber);
                    linkAliasNumber++;
                } else if(fieldType.equals("user")) {
                    field = new UserField(fieldName, defn);
                } else {
                    throw new OAPIException("Unknown data type '" + fieldType + "' in field definition for " + name + "." + fieldName);
                }
                fieldList.add(field);
            }
        }

        // Convert list to normal Java array
        this.fields = fieldList.toArray(new Field[fieldList.size()]);

        // Create the JavaScript object factory function
        Scriptable mainScope = runtime.getJavaScriptScope();
        Scriptable sharedScope = runtime.getSharedJavaScriptScope();
        Scriptable dbObject = (Scriptable)sharedScope.get("$DbObject", mainScope); // ConsString is checked
        Function jsClassConstructor = (Function)dbObject.get("$makeFactoryFunction", dbObject);
        this.factory = (Function)jsClassConstructor.call(runtime.getContext(), dbObject, jsClassConstructor, new Object[]{this, fields, methods});
    }

    // --------------------------------------------------------------------------------------------------------------
    public String jsGet_name() {
        return jsName;
    }

    public Scriptable jsGet_namespace() {
        return this.namespace;
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable jsFunction_create(Scriptable initialValues) {
        Runtime runtime = Runtime.getCurrentRuntime();
        return (Scriptable)this.factory.call(runtime.getContext(), this.factory, this.factory, new Object[]{initialValues});
    }

    public Scriptable jsFunction_load(int id) throws java.sql.SQLException {
        ParameterIndicies indicies = makeParameterIndicies();
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        Statement statement = db.createStatement();
        Scriptable object = null;
        try {
            StringBuilder select = new StringBuilder("SELECT ");
            this.appendColumnNamesForSelect(1, this.getDatabaseTableName(), select, indicies);
            select.append(" FROM ");
            select.append(this.getDatabaseTableName());
            select.append(" WHERE id=" + id);
            ResultSet results = statement.executeQuery(select.toString());
            ArrayList<Scriptable> objects = jsObjectsFromResultsSet(results, 1 /* results size hint */, indicies, null /* no includes */);
            if(objects.size() == 1) {
                object = objects.get(0);
            } else if(objects.size() != 0) {
                throw new OAPIException("Expectations not met; database returns more than one object");
            }
            results.close();
        } finally {
            statement.close();
        }

        return object;
    }

    public Scriptable jsFunction_select() {
        return Runtime.createHostObjectInCurrentRuntime("$DbSelect", this);
    }

    public void jsFunction_createNewRow(Scriptable row) throws java.sql.SQLException {
        StringBuilder sql = new StringBuilder("INSERT INTO ");
        sql.append(this.getDatabaseTableName());
        sql.append(" (");
        // Find the last field
        Field lastField = null;
        if(this.fields.length > 0) {
            lastField = this.fields[this.fields.length - 1];
        }
        // Build the insert fields
        for(Field field : fields) {
            field.appendInsertColumnName(sql);
            if(field != lastField) {
                sql.append(',');
            }
        }
        sql.append(") VALUES(");
        for(Field field : fields) {
            field.appendInsertMarker(sql);
            if(field != lastField) {
                sql.append(',');
            }
        }
        sql.append(") RETURNING id");

        Scriptable rowValues = (Scriptable)row.get("$values", row);

        // Run the SQL
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        PreparedStatement statement = db.prepareStatement(sql.toString());
        try {
            int parameterIndex = 1;
            for(Field field : fields) {
                parameterIndex = field.setStatementField(parameterIndex, statement, rowValues);
            }
            ResultSet results = statement.executeQuery();
            if(!results.next()) {
                throw new OAPIException("Create row didn't return an id");
            }
            int id = results.getInt(1);

            // Store the id in the row object
            row.put("id", row, new Integer(id));
        } finally {
            statement.close();
        }
    }

    public void jsFunction_saveChangesToRow(int id, Scriptable row) throws java.sql.SQLException {
        if(id <= 0) {
            throw new OAPIException("Bad id value for updating row");
        }

        // Get the changed values from the row object
        Object rowValuesO = row.get("$changes", row); // ConsString is checked
        if(rowValuesO == Scriptable.NOT_FOUND) {
            // Nothing has been changed, so just return silently.
            return;
        }
        Scriptable rowValues = (Scriptable)rowValuesO;

        // Build the SQL to update it
        StringBuilder update = new StringBuilder("UPDATE ");
        update.append(this.getDatabaseTableName());
        update.append(" SET ");
        boolean needsComma = false;
        int parameterIndex = 1;
        ParameterIndicies indicies = makeParameterIndicies();
        for(Field field : this.fields) {
            int nextParameterIndex = field.appendUpdateSQL(update, needsComma, rowValues, parameterIndex, indicies);
            if(nextParameterIndex != parameterIndex) {
                parameterIndex = nextParameterIndex;
                needsComma = true;
            }
        }
        update.append(" WHERE id=");
        update.append(id);

        // Execute the SQL
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        PreparedStatement statement = db.prepareStatement(update.toString());
        try {
            for(Field field : this.fields) {
                field.setUpdateField(statement, rowValues, indicies);
            }
            statement.execute();
        } finally {
            statement.close();
        }
    }

    public boolean jsFunction_deleteRow(int id) throws java.sql.SQLException {
        if(id <= 0) {
            throw new OAPIException("Bad id value for deleting row");
        }

        // Update database
        boolean wasDeleted = false;
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        Statement statement = db.createStatement();
        try {
            int count = statement.executeUpdate("DELETE FROM " + this.getDatabaseTableName() + " WHERE id=" + id);
            if(count == 1) {
                wasDeleted = true;
            } else if(count != 0) {
                throw new RuntimeException("Logic error - more than one row deleted");
            }
        } finally {
            statement.close();
        }

        return wasDeleted;
    }

    // --------------------------------------------------------------------------------------------------------------
    public void setupStorage(Connection db) throws java.sql.SQLException {
        String postgresSchema = this.namespace.getPostgresSchemaName();

        // Does this table exist?
        boolean tableExists = false;
        String checkSql = "SELECT table_name FROM information_schema.tables WHERE table_schema='" + postgresSchema + "' AND table_name='" + this.getDatabaseTableName() + "'";
        // OK to generate the SQL like this - schema name is internally generated, and table name is checked
        Statement checkStatement = db.createStatement();
        try {
            ResultSet results = checkStatement.executeQuery(checkSql);
            if(results.next()) {
                tableExists = true;
            }
            results.close();
        } finally {
            checkStatement.close();
        }

        // TODO: JavaScript tables should check and migrate a table definition + index definitions if it already exists
        // Create the table?
        if(!tableExists) {
            // Generate the SQL for the table and indicies
            ArrayList<String> sqlStatements = new ArrayList<String>(16);
            StringBuilder create = new StringBuilder("CREATE TABLE ");
            create.append(postgresSchema);
            create.append('.');
            create.append(this.getDatabaseTableName());
            create.append(" (\nid SERIAL PRIMARY KEY");
            for(Field field : fields) {
                create.append(",\n");
                create.append(field.generateSqlDefinition(this));
            }
            create.append("\n);");
            sqlStatements.add(create.toString());

            // Generate the index creation SQL
            int indexIndex = 0;
            for(Field field : fields) {
                String indexSql = field.generateIndexSqlDefinition(this, indexIndex++);
                if(indexSql != null) {
                    sqlStatements.add(indexSql);
                }
            }

            // Run the SQL to create the table
            Statement createStatement = db.createStatement();
            try {
                for(String sql : sqlStatements) {
                    createStatement.executeUpdate(sql);
                }
            } finally {
                createStatement.close();
            }
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    public Scriptable[] executeQuery(JdSelect query) throws java.sql.SQLException {
        return (Scriptable[])buildAndExecuteQuery(query, false /* results */);
    }

    public int executeCount(JdSelect query) throws java.sql.SQLException {
        return (Integer)buildAndExecuteQuery(query, true /* count only */);
    }

    private Object buildAndExecuteQuery(JdSelect query, boolean returnCount) throws java.sql.SQLException {
        ParameterIndicies indicies = makeParameterIndicies();
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        // Build SELECT statement
        String from = this.getDatabaseTableName() + " AS m";
        StringBuilder select = new StringBuilder("SELECT ");
        if(returnCount) {
            select.append("COUNT(*) ");
        }
        // Field names & linked table FROM clause generation
        int parameterIndexStart = 0;
        if(!returnCount) // only include field names when requesting results
        {
            parameterIndexStart = this.appendColumnNamesForSelect(1, "m", select, indicies);
        }
        // Load other tables at the same time?
        JdTable.LinkField[] includeFields = query.getIncludes();
        IncludedTable includes[] = null;
        if(includeFields != null) {
            includes = new IncludedTable[includeFields.length];
            // Go through each of the fields
            for(int includeIndex = 0; includeIndex < includeFields.length; ++includeIndex) {
                // Get info about included tables
                JdTable.LinkField field = includeFields[includeIndex];
                JdTable otherTable = this.namespace.getTable(field.getOtherTableName());
                String otherAlias = field.getNameForQueryAlias();
                ParameterIndicies otherIndicies = otherTable.makeParameterIndicies();
                includes[includeIndex] = new IncludedTable(otherTable, field, otherIndicies);
                // Field names?
                if(!returnCount) // only include field names when requesting results
                {
                    // Ask all the other tables to add their fields
                    select.append(',');
                    parameterIndexStart = otherTable.appendColumnNamesForSelect(parameterIndexStart, otherAlias, select, otherIndicies);
                }
                // Adjust the FROM statement
                from = "(" + from + " LEFT JOIN " + otherTable.getDatabaseTableName() + " AS " + otherAlias + " ON m." + field.getDbName() + "=" + otherAlias + ".id)";
            }
        }
        // Finish the statement
        select.append(" FROM ");
        select.append(from);
        String where = query.generateWhereSql("m");
        if(where != null) {
            select.append(" WHERE ");
            select.append(where);
        }
        if(!returnCount) // only include order when requesting results
        {
            String order = query.generateOrderSql("m");
            if(order != null) {
                select.append(" ORDER BY ");
                select.append(order);
            }
        }
        String limit = query.generateLimitAndOffsetSql();
        if(limit != null) {
            select.append(limit);
        }

        // Run the query
        Object output = null;
        PreparedStatement statement = db.prepareStatement(select.toString());
        try {
            if(where != null) {
                query.setWhereValues(statement);
            }
            ResultSet results = statement.executeQuery();
            if(returnCount) {
                if(results.next()) {
                    output = results.getInt(1);
                }
            } else {
                ArrayList<Scriptable> objects = jsObjectsFromResultsSet(results, 100 /* results size hint */, indicies, includes);
                output = objects.toArray(new Scriptable[objects.size()]);
            }
            results.close();
        } finally {
            statement.close();
        }

        return output;
    }

    // --------------------------------------------------------------------------------------------------------------
    public int executeDelete(JdSelect query) throws java.sql.SQLException {
        if(null != query.getIncludes()) {
            throw new OAPIException("deleteAll() cannot use selects which include other tables, or where clauses which refer to a field in another table via a link field. Remove include() statements and check your where() clauses.");
        }
        ParameterIndicies indicies = makeParameterIndicies();
        Connection db = Runtime.currentRuntimeHost().getSupportRoot().getJdbcConnection();
        int numberDeleted = 0;
        // Build DELETE statement
        StringBuilder del = new StringBuilder("DELETE FROM ");
        String tableName = this.getDatabaseTableName();
        del.append(tableName);
        String where = query.generateWhereSql(tableName);
        if(where != null) {
            del.append(" WHERE ");
            del.append(where);
        }
        // Run the query
        PreparedStatement statement = db.prepareStatement(del.toString());
        try {
            if(where != null) {
                query.setWhereValues(statement);
            }
            numberDeleted = statement.executeUpdate();
        } finally {
            statement.close();
        }
        return numberDeleted;
    }

    // --------------------------------------------------------------------------------------------------------------
    private int appendColumnNamesForSelect(int parameterIndexStart, String tableAlias, StringBuilder builder, ParameterIndicies indicies) {
        int parameterIndex = parameterIndexStart;
        // id column goes first, store the parameter index for the read later on
        indicies.set(parameterIndex++);
        builder.append(tableAlias);
        builder.append(".id");

        // Append column names
        for(Field field : fields) {
            builder.append(',');
            parameterIndex = field.appendColumnNamesForSelect(parameterIndex, tableAlias, builder, indicies);
        }

        return parameterIndex;
    }

    private ArrayList<Scriptable> jsObjectsFromResultsSet(ResultSet results, int capacityHint, ParameterIndicies indicies, IncludedTable[] includes)
            throws java.sql.SQLException {
        Runtime runtime = Runtime.getCurrentRuntime();
        Context context = runtime.getContext();
        Scriptable scope = runtime.getJavaScriptScope();
        ArrayList<Scriptable> objects = new ArrayList<Scriptable>(capacityHint);

        // Turn the rows into a list of JavaScript objects
        while(results.next()) {
            Scriptable o = readJsObjectFromResultSet(results, indicies, scope, context);
            if(o == null) {
                throw new RuntimeException("logic error, no results when results expected");
            }
            // Read other objects included in this SELECT statement
            if(includes != null) {
                // Objects should be added to the $values object with a suffix on the field name
                Scriptable oValues = (Scriptable)o.get("$values", o);
                for(IncludedTable include : includes) {
                    Scriptable i = include.table.readJsObjectFromResultSet(results, include.indicies, scope, context);
                    if(i != null) {
                        oValues.put(include.valueKey, oValues, i);
                    }
                }
            }
            objects.add(o);
        }

        return objects;
    }

    private Scriptable readJsObjectFromResultSet(ResultSet results, ParameterIndicies indicies, Scriptable scope, Context context)
            throws java.sql.SQLException {
        indicies.nextRow();
        int id = results.getInt(indicies.get());

        // Check to see there was actually an object there (might be an null column for an includes)
        if(results.wasNull()) {
            return null;
        }

        Scriptable o = (Scriptable)this.factory.call(context, this.factory, this.factory, new Object[]{});
        o.put("id", o, id);
        Scriptable oValues = (Scriptable)o.get("$values", o);

        for(Field field : this.fields) {
            field.setValueInJsObjectFromResultSet(results, oValues, scope, indicies);
        }

        return o;
    }

    private static final class IncludedTable {
        public final JdTable table;
        public final Field field;
        public final ParameterIndicies indicies;
        public final String valueKey; // for the $values array

        IncludedTable(JdTable table, Field field, ParameterIndicies indicies) {
            this.table = table;
            this.field = field;
            this.indicies = indicies;
            this.valueKey = field.getJsName() + "_obj";
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    // Store the parameter indicies for the table fields in SQL statements
    private static final class ParameterIndicies {
        private int[] indicies;
        private int setPos;
        private int getPos;

        ParameterIndicies(int length) {
            this.indicies = new int[length];
            this.setPos = 0;
            this.getPos = 0;
        }

        public void set(int index) {
            this.indicies[this.setPos++] = index;
        }

        public int get() {
            return this.indicies[this.getPos++];
        }

        public void nextRow() {
            this.getPos = 0;
        }
    }

    private ParameterIndicies makeParameterIndicies() {
        // Each field needs an entry, plus one for the id field.
        return new ParameterIndicies(1 + this.fields.length);
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static abstract class Field {
        protected String dbName;  // name in the database
        protected String jsName;  // name in the javascript
        protected boolean nullable;
        protected boolean indexed;
        protected boolean uniqueIndex;
        protected String[] otherIndexFields;

        public Field(String name, Scriptable defn) {
            this.dbName = name.toLowerCase();
            if(PostgresqlReservedWords.isReserved(this.dbName)) {
                this.dbName = "_" + this.dbName;   // _ prefix ensures that it won't clash with reserved words
            }
            this.jsName = name;
            this.nullable = JsGet.booleanWithDefault("nullable", defn, false);
            this.indexed = JsGet.booleanWithDefault("indexed", defn, false);
            this.uniqueIndex = JsGet.booleanWithDefault("uniqueIndex", defn, false);
            // Read, check and convert list of fields this is indexed with
            Scriptable indexedWithArray = JsGet.scriptable("indexedWith", defn);
            if(indexedWithArray != null) {
                this.indexed = true;
                Object[] elements = Runtime.getCurrentRuntime().getContext().getElements(indexedWithArray);
                this.otherIndexFields = new String[elements.length];
                int i = 0;
                for(Object element : elements) {
                    if(!(element instanceof CharSequence)) {
                        throw new OAPIException("Field " + jsName + " has bad field name in indexedWith array");
                    }
                    String elementName = ((CharSequence)element).toString();
                    JdNamespace.checkNameIsAllowed(elementName);    // paranoid, will also be checked implicity with getField call later
                    this.otherIndexFields[i++] = elementName;
                }
            }
        }

        public String getJsName() {
            return jsName;
        }

        public String getDbName() {
            return dbName;
        }

        public abstract String sqlDataType();

        public abstract int jdbcDataType();

        public abstract boolean jsNonNullObjectIsCompatible(Object object);

        public boolean jsObjectIsCompatible(Object object) {
            if(object == null) {
                return this.nullable ? true : false;
            }
            return jsNonNullObjectIsCompatible(object);
        }

        public void checkNonNullJsObjectForComparison(Object object, String comparison) {
            // Subclasses should throw an exception if they don't like the value
        }

        protected void checkForForbiddenNullValue(Object object) {
            if(object == null && !(this.nullable)) {
                throw new OAPIException(this.jsName + " cannot be null");
            }
        }

        public String generateSqlDefinition(JdTable table) {
            StringBuilder defn = new StringBuilder(this.dbName);
            defn.append(" ");
            defn.append(this.sqlDataType());
            if(!this.nullable) {
                defn.append(" NOT NULL");
            }
            return defn.toString();
        }

        public String generateIndexSqlDefinition(JdTable table, int indexIndex) {
            if(!this.indexed) {
                return null;
            }

            StringBuilder create = new StringBuilder(this.uniqueIndex ? "CREATE UNIQUE INDEX " : "CREATE INDEX ");
            create.append(table.getDatabaseTableName());
            create.append("_i" + indexIndex);
            create.append(" ON ");
            create.append(table.getDatabaseTableName());
            create.append("(");
            create.append(this.generateIndexSqlDefinitionFields());
            if(this.otherIndexFields != null) {
                for(String fieldName : this.otherIndexFields) {
                    // Check the field actually exists
                    Field otherField = table.getField(fieldName);
                    if(otherField == null) {
                        throw new OAPIException("Field " + fieldName + " was requested in index for field " + jsName + " but does not exist in table");
                    }
                    create.append(',');
                    create.append(otherField.generateIndexSqlDefinitionFields());
                }
            }
            create.append(");");
            return create.toString();
        }

        public String generateIndexSqlDefinitionFields() {
            return getDbName();
        }

        // INSERT
        public void appendInsertColumnName(StringBuilder builder) {
            builder.append(this.dbName);
        }

        public void appendInsertMarker(StringBuilder builder) {
            builder.append('?');
        }

        public abstract int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException;

        // UPDATE
        public int appendUpdateSQL(StringBuilder builder, boolean needsComma, Scriptable values, int parameterIndex, ParameterIndicies indicies) {
            Object value = values.get(jsName, values); // ConsString is checked
            if(value == Scriptable.NOT_FOUND) {
                indicies.set(-1);   // mark as not being updated in this update
                return parameterIndex;
            } else {
                indicies.set(parameterIndex);   // store location for setUpdateField
                if(needsComma) {
                    builder.append(',');
                }
                builder.append(dbName);
                builder.append("=?");
                return parameterIndex + 1;
            }
        }

        public void setUpdateField(PreparedStatement statement, Scriptable values, ParameterIndicies indicies) throws java.sql.SQLException {
            int updateColumnIndex = indicies.get();
            if(updateColumnIndex != -1) {
                setStatementField(updateColumnIndex, statement, values);
            }
        }

        // SELECT
        public int appendColumnNamesForSelect(int parameterIndex, String tableAlias, StringBuilder builder, ParameterIndicies indicies) {
            builder.append(tableAlias);
            builder.append('.');
            builder.append(dbName);
            // Store read column index for later and return the next index
            indicies.set(parameterIndex);
            return parameterIndex + 1;
        }

        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value) {
            appendWhereSqlFieldName(where, tableAlias);
            where.append(' ');
            if(value == null) {
                if(comparison.equals("=")) {
                    where.append("IS NULL");
                } else if(comparison.equals("<>")) {
                    where.append("IS NOT NULL");
                } else {
                    throw new OAPIException("Can't use a comparison other than = for a null value (in field " + jsName + ")");
                }
            } else {
                where.append(comparison);
                where.append(" ");
                appendWhereSqlValueMarker(where);
            }
        }

        public void appendWhereSqlFieldName(StringBuilder where, String tableAlias) {
            where.append(tableAlias);
            where.append('.');
            where.append(dbName);
        }

        public void appendWhereSqlValueMarker(StringBuilder where) {
            where.append("?");
        }

        public void appendOrderSql(StringBuilder clause, String tableAlias, boolean descending) {
            clause.append(tableAlias);
            clause.append('.');
            clause.append(dbName);
            if(descending) {
                clause.append(" DESC");
            }
        }

        public abstract void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException;

        public int setWhereValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            if(value == null) {
                return parameterIndex;
            } else {
                this.setWhereNotNullValue(parameterIndex, statement, value);
                return parameterIndex + 1;
            }
        }

        // READING RESULTS
        public void setValueInJsObjectFromResultSet(ResultSet results, Scriptable values, Scriptable scope, ParameterIndicies indicies)
                throws java.sql.SQLException {
            Object value = getValueFromResultSet(results, indicies);
            if(value == null || (nullable && results.wasNull())) {
                values.put(jsName, values, null);
            } else {
                values.put(jsName, values, value);
            }
        }

        protected abstract Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException;
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class TextField extends Field {
        private boolean isCaseInsensitive;

        public TextField(String name, Scriptable defn) {
            super(name, defn);
            this.isCaseInsensitive = JsGet.booleanWithDefault("caseInsensitive", defn, false);
        }

        @Override
        public String sqlDataType() {
            return "TEXT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.CHAR;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof CharSequence;
        }

        @Override
        public void checkNonNullJsObjectForComparison(Object object, String comparison) {
            // LIKE operator has extra constraints
            if(comparison.equals("LIKE")) {
                String string = ((CharSequence)object).toString(); // know this works because of jsNonNullObjectIsCompatible() check
                if(string.length() < 1) {
                    throw new OAPIException("Value for a LIKE where clause must be at least one character long.");
                }
                char firstChar = string.charAt(0);
                if(firstChar == '_' || firstChar == '%') {
                    throw new OAPIException("Value for a LIKE clause may not have a wildcard as the first character.");
                }
            }
        }

        @Override
        public String getDbName() {
            return this.isCaseInsensitive ? "lower(" + super.getDbName() + ")" : super.getDbName();
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            String s = JsGet.string(this.jsName, values);
            checkForForbiddenNullValue(s);
            statement.setString(parameterIndex, s);
            return parameterIndex + 1;
        }

        @Override
        public void appendWhereSqlFieldName(StringBuilder where, String tableAlias) {
            if(this.isCaseInsensitive) {
                where.append("lower(");
            }
            super.appendWhereSqlFieldName(where, tableAlias);
            if(this.isCaseInsensitive) {
                where.append(")");
            }
        }

        @Override
        public void appendWhereSqlValueMarker(StringBuilder where) {
            where.append(this.isCaseInsensitive ? "lower(?)" : "?");
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setString(parameterIndex, ((CharSequence)value).toString());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getString(indicies.get()); // ConsString is checked (indicies is not a ScriptableObject)
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class DateTimeField extends Field {
        public DateTimeField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "TIMESTAMP";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.TIMESTAMP;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return Runtime.getCurrentRuntime().isAcceptedJavaScriptDateObject(object);
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Date d = JsGet.date(this.jsName, values);
            checkForForbiddenNullValue(d);
            statement.setTimestamp(parameterIndex, (d == null) ? null : (new java.sql.Timestamp(d.getTime())));
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            value = Runtime.getCurrentRuntime().convertIfJavaScriptLibraryDate(value); // support various JavaScript libraries
            Date d = (Date)Context.jsToJava(value, ScriptRuntime.DateClass);
            statement.setTimestamp(parameterIndex, new java.sql.Timestamp(d.getTime()));
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            java.sql.Timestamp timestamp = results.getTimestamp(indicies.get());
            // Need to create a JavaScript object - automatic conversion doesn't work for these
            return (timestamp == null) ? null : Runtime.createHostObjectInCurrentRuntime("Date", timestamp.getTime());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class DateField extends DateTimeField {
        public DateField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "DATE";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.DATE;
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class TimeField extends Field {
        public TimeField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "TIME WITHOUT TIME ZONE";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.TIME;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            // A simple, and not entirely accurate test. But good enough for these purposes.
            if(!(object instanceof Scriptable)) {
                return false;
            }
            Scriptable prototype = ((Scriptable)object).getPrototype();
            return (prototype.get("$is_dbtime", prototype) instanceof CharSequence);
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Scriptable dbtime = JsGet.scriptable(this.jsName, values);
            checkForForbiddenNullValue(dbtime);
            java.sql.Time t = TimeField.convertDBTime(dbtime);
            if(t == null) {
                statement.setNull(parameterIndex, java.sql.Types.TIME);
            } else {
                statement.setTime(parameterIndex, t);
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setTime(parameterIndex, convertDBTime((Scriptable)value));
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            java.sql.Time t = results.getTime(indicies.get());
            if(t == null || results.wasNull()) {
                return null;
            }
            return Runtime.createHostObjectInCurrentRuntime("DBTime", t.getHours(), t.getMinutes(), t.getSeconds());
        }

        static java.sql.Time convertDBTime(Scriptable dbtime) {
            if(dbtime == null) {
                return null;
            }
            long milliseconds = 0;
            Object hours = dbtime.get("$hours", dbtime); // ConsString is checked
            Object minutes = dbtime.get("$minutes", dbtime); // ConsString is checked
            Object seconds = dbtime.get("$seconds", dbtime); // ConsString is checked
            if(hours instanceof Number) {
                milliseconds += ((Number)hours).longValue() * (60 * 60 * 1000);
            } else {
                return null;
            }   // should at least have an hour
            if(minutes instanceof Number) {
                milliseconds += ((Number)minutes).longValue() * (60 * 1000);
            }
            if(seconds instanceof Number) {
                milliseconds += ((Number)seconds).longValue() * (1000);
            }
            return new java.sql.Time(milliseconds);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class BooleanField extends Field {
        public BooleanField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "BOOLEAN";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.BOOLEAN;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof Boolean;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Boolean b = JsGet.booleanObject(this.jsName, values);
            checkForForbiddenNullValue(b);
            if(b == null) {
                statement.setNull(parameterIndex, java.sql.Types.BOOLEAN);
            } else {
                statement.setBoolean(parameterIndex, b);
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setBoolean(parameterIndex, (Boolean)value);
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getBoolean(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class SmallIntField extends Field {
        public SmallIntField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "SMALLINT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.SMALLINT;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof Number;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Number d = JsGet.number(this.jsName, values);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.SMALLINT);
            } else {
                statement.setShort(parameterIndex, d.shortValue());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setShort(parameterIndex, ((Number)value).shortValue());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getInt(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class IntField extends Field {
        public IntField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "INT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.INTEGER;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof Number;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Number d = JsGet.number(this.jsName, values);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.INTEGER);
            } else {
                statement.setInt(parameterIndex, d.intValue());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setInt(parameterIndex, ((Number)value).intValue());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getInt(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class BigIntField extends Field {
        public BigIntField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "BIGINT";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.BIGINT;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof Number;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Number d = JsGet.number(this.jsName, values);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.BIGINT);
            } else {
                statement.setLong(parameterIndex, d.longValue());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setLong(parameterIndex, ((Number)value).longValue());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getLong(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class FloatField extends Field {
        public FloatField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            return "DOUBLE PRECISION";
        }

        @Override
        public int jdbcDataType() {
            return java.sql.Types.DOUBLE;
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof Number;
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            Number d = JsGet.number(this.jsName, values);
            checkForForbiddenNullValue(d);
            if(d == null) {
                statement.setNull(parameterIndex, java.sql.Types.DOUBLE);
            } else {
                statement.setDouble(parameterIndex, d.doubleValue());
            }
            return parameterIndex + 1;
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setDouble(parameterIndex, ((Number)value).doubleValue());
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            return results.getDouble(indicies.get());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class ObjRefField extends Field {
        public ObjRefField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            throw new RuntimeException("shouldn't call sqlDataType for ObjRefField");
        }

        @Override
        public int jdbcDataType() {
            throw new RuntimeException("shouldn't call jdbcDataType for ObjRefField");
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof KObjRef;
        }

        @Override
        public String generateSqlDefinition(JdTable table) {
            StringBuilder defn = new StringBuilder(this.dbName);
            defn.append(" INT");
            if(!this.nullable) {
                defn.append(" NOT NULL");
            }
            return defn.toString();
        }

        @Override
        public String generateIndexSqlDefinitionFields() {
            return getDbName();
        }

        // INSERT
        @Override
        public void appendInsertColumnName(StringBuilder builder) {
            builder.append(this.dbName);
        }

        @Override
        public void appendInsertMarker(StringBuilder builder) {
            builder.append("?");
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            KObjRef ref = (KObjRef)JsGet.objectOfClass(this.jsName, values, KObjRef.class);
            checkForForbiddenNullValue(ref);
            if(ref == null) {
                statement.setNull(parameterIndex, java.sql.Types.INTEGER);
            } else {
                statement.setInt(parameterIndex, ref.jsGet_objId());
            }
            return parameterIndex + 1;
        }

        // UPDATE
        @Override
        public int appendUpdateSQL(StringBuilder builder, boolean needsComma, Scriptable values, int parameterIndex, ParameterIndicies indicies) {
            Object value = values.get(jsName, values); // ConsString is checked
            if(value == Scriptable.NOT_FOUND) {
                indicies.set(-1);   // not in this update
                return parameterIndex;
            } else {
                indicies.set(parameterIndex);   // in this update
                if(needsComma) {
                    builder.append(',');
                }
                builder.append(dbName);
                builder.append("=?");
                return parameterIndex + 1;
            }
        }

        // SELECT
        @Override
        public int appendColumnNamesForSelect(int parameterIndex, String tableAlias, StringBuilder builder, ParameterIndicies indicies) {
            builder.append(tableAlias);
            builder.append('.');
            builder.append(dbName);
            // Store read column index for later and return the next index
            indicies.set(parameterIndex);
            return parameterIndex + 1;
        }

        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value) {
            boolean isEqualComparison = comparison.equals("=");
            if(!(isEqualComparison || comparison.equals("<>"))) {
                throw new OAPIException("Can't use a comparison other than = for a ref field in a where() clause");
            }
            if(value == null) {
                if(isEqualComparison) {
                    where.append(String.format("%1$s.%2$s IS NULL", tableAlias, dbName));
                } else {
                    where.append(String.format("%1$s.%2$s IS NOT NULL", tableAlias, dbName));
                }
            } else {
                where.append(String.format("(%1$s.%2$s %3$s ?)", tableAlias, dbName, comparison));
            }
        }

        @Override
        public void appendOrderSql(StringBuilder clause, String tableAlias, boolean descending) {
            // TODO: In JavaScript database API, ordering by ref should join in the os_objects table and sort on title (if efficient)
            clause.append(tableAlias);
            clause.append('.');
            clause.append(dbName);
            if(descending) {
                clause.append(" DESC");
            }
        }

        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            throw new RuntimeException("logic error");
        }

        public int setWhereValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            if(value == null) {
                // Do nothing - using IS NULL comparisons
            } else {
                statement.setInt(parameterIndex, ((KObjRef)value).jsGet_objId());
            }
            return parameterIndex + 1;
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            int readColumnIndex = indicies.get();
            int objId = results.getInt(readColumnIndex);
            if(results.wasNull()) {
                return null;
            }
            return Runtime.createHostObjectInCurrentRuntime("$Ref", objId);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static class LinkField extends IntField {
        // LinkFields include the name used in query aliases so the name is easily available in the query generation process,
        // especially for when the value being compared is in a joined table. Can't use the field name as the alias, because
        // it might clash with the name used for the alias of the queried table.
        private String nameForQueryAlias;
        private String otherTableName;

        public LinkField(String name, Scriptable defn, String nameForQueryAlias) {
            super(name, defn);
            this.nameForQueryAlias = nameForQueryAlias;
            String linkedTable = JsGet.string("linkedTable", defn);
            this.otherTableName = (linkedTable != null) ? linkedTable : name;
            JdNamespace.checkNameIsAllowed(this.otherTableName);
        }

        public String getOtherTableName() {
            return this.otherTableName;
        }

        public String getNameForQueryAlias() {
            return this.nameForQueryAlias;
        }

        @Override
        public String generateSqlDefinition(JdTable table) {
            JdTable otherTable = table.getNamespace().getTable(this.otherTableName);
            if(otherTable == null) {
                throw new OAPIException("Table name " + this.otherTableName + " has not been defined yet.");
            }
            StringBuilder defn = new StringBuilder(super.generateSqlDefinition(table));
            defn.append(" REFERENCES ");
            defn.append(otherTable.getDatabaseTableName());
            defn.append("(id)");
            return defn.toString();
        }

        @Override
        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value) {
            if(!(comparison.equals("=") || comparison.equals("<>"))) {
                throw new OAPIException("Link fields can only use the = and <> comparisons in where clauses.");
            }
            super.appendWhereSql(where, tableAlias, comparison, value);
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    protected static class UserField extends IntField {
        public UserField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof KUser;
        }

        @Override
        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value) {
            if(!(comparison.equals("=") || comparison.equals("<>"))) {
                throw new OAPIException("User fields can only use the = and <> comparisons in where clauses.");
            }
            super.appendWhereSql(where, tableAlias, comparison, value);
        }

        @Override
        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            statement.setInt(parameterIndex, ((KUser)value).jsGet_id());
        }
    }

    // --------------------------------------------------------------------------------------------------------------
    private static class FileField extends Field {
        public FileField(String name, Scriptable defn) {
            super(name, defn);
        }

        @Override
        public String sqlDataType() {
            throw new RuntimeException("shouldn't call sqlDataType for FileField");
        }

        @Override
        public int jdbcDataType() {
            throw new RuntimeException("shouldn't call jdbcDataType for FileField");
        }

        @Override
        public boolean jsNonNullObjectIsCompatible(Object object) {
            return object instanceof KStoredFile;
        }

        @Override
        public String generateSqlDefinition(JdTable table) {
            StringBuilder defn = new StringBuilder(this.dbName);
            defn.append("_d TEXT"); // digest
            if(!this.nullable) {
                defn.append(" NOT NULL");
            }
            defn.append(", ");
            defn.append(this.dbName);
            defn.append("_s BIGINT"); // size
            if(!this.nullable) {
                defn.append(" NOT NULL");
            }
            return defn.toString();
        }

        @Override
        public String generateIndexSqlDefinitionFields() {
            return String.format("%1$s_d,%1$s_s", this.dbName);
        }

        // INSERT
        @Override
        public void appendInsertColumnName(StringBuilder builder) {
            builder.append(this.dbName);
            builder.append("_d,");
            builder.append(this.dbName);
            builder.append("_s");
        }

        @Override
        public void appendInsertMarker(StringBuilder builder) {
            builder.append("?,?");
        }

        @Override
        public int setStatementField(int parameterIndex, PreparedStatement statement, Scriptable values) throws java.sql.SQLException {
            KStoredFile file = (KStoredFile)JsGet.objectOfClass(this.jsName, values, KStoredFile.class);
            if(file == null) {
                statement.setNull(parameterIndex, java.sql.Types.CHAR);
                statement.setNull(parameterIndex + 1, java.sql.Types.INTEGER);
            } else {

                statement.setString(parameterIndex, file.jsGet_digest());
                statement.setLong(parameterIndex + 1, file.jsGet_fileSize());
            }
            return parameterIndex + 2;
        }

        // UPDATE
        @Override
        public int appendUpdateSQL(StringBuilder builder, boolean needsComma, Scriptable values, int parameterIndex, ParameterIndicies indicies) {
            Object value = values.get(jsName, values); // ConsString is checked
            if(value == Scriptable.NOT_FOUND) {
                indicies.set(-1);   // not in this update
                return parameterIndex;
            } else {
                indicies.set(parameterIndex);   // in this update
                if(needsComma) {
                    builder.append(',');
                }
                builder.append(dbName);
                builder.append("_d=?,");
                builder.append(dbName);
                builder.append("_s=?");
                return parameterIndex + 2;
            }
        }

        // SELECT
        @Override
        public int appendColumnNamesForSelect(int parameterIndex, String tableAlias, StringBuilder builder, ParameterIndicies indicies) {
            builder.append(tableAlias);
            builder.append('.');
            builder.append(dbName);
            builder.append("_d,");
            builder.append(tableAlias);
            builder.append('.');
            builder.append(dbName);
            builder.append("_s");
            // Store read column index for later and return the next index
            indicies.set(parameterIndex);
            return parameterIndex + 2;
        }

        public void appendWhereSql(StringBuilder where, String tableAlias, String comparison, Object value) {
            boolean isEqualComparison = comparison.equals("=");
            if(!(isEqualComparison || comparison.equals("<>"))) {
                throw new OAPIException("Can't use a comparison other than = for a file field in a where() clause");
            }
            if(value == null) {
                if(isEqualComparison) {
                    where.append(String.format("%1$s.%2$s_d IS NULL", tableAlias, dbName));
                } else {
                    where.append(String.format("%1$s.%2$s_d IS NOT NULL", tableAlias, dbName));
                }
            } else {
                where.append(String.format("(%1$s.%2$s_d %3$s ? AND %1$s.%2$s_s %3$s ?)", tableAlias, dbName, comparison));
            }
        }

        @Override
        public void appendOrderSql(StringBuilder clause, String tableAlias, boolean descending) {
            // Ordering on file doesn't really make sense, but there you go
            clause.append(tableAlias);
            clause.append('.');
            clause.append(dbName);
            clause.append("_d");
            if(descending) {
                clause.append(" DESC");
            }
            clause.append(',');
            clause.append(tableAlias);
            clause.append('.');
            clause.append(dbName);
            clause.append("_s");
            if(descending) {
                clause.append(" DESC");
            }
        }

        public void setWhereNotNullValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            throw new RuntimeException("logic error");
        }

        public int setWhereValue(int parameterIndex, PreparedStatement statement, Object value) throws java.sql.SQLException {
            if(value == null) {
                // Do nothing - using IS NULL comparisons
            } else {
                statement.setString(parameterIndex, ((KStoredFile)value).jsGet_digest());
                statement.setLong(parameterIndex + 1, ((KStoredFile)value).jsGet_fileSize());
            }
            return parameterIndex + 2;
        }

        @Override
        protected Object getValueFromResultSet(ResultSet results, ParameterIndicies indicies) throws java.sql.SQLException {
            int readColumnIndex = indicies.get();
            String digest = results.getString(readColumnIndex);
            if(results.wasNull()) {
                return null;
            }
            long fileSize = results.getLong(readColumnIndex + 1);
            return KStoredFile.fromDigestAndSize(digest, fileSize);
        }
    }

}
