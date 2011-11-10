/* Copyright 2011 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution. 
 */

public class Geary.Sqlite.MessageLocationTable : Geary.Sqlite.Table {
    // This row *must* match the order in the schema
    public enum Column {
        ID,
        MESSAGE_ID,
        FOLDER_ID,
        ORDERING
    }
    
    public MessageLocationTable(Geary.Sqlite.Database db, SQLHeavy.Table table) {
        base (db, table);
    }
    
    public async int64 create_async(Transaction? transaction, MessageLocationRow row,
        Cancellable? cancellable) throws Error {
        Transaction locked = yield obtain_lock_async(transaction, "MessageLocationTable.create_async",
            cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "INSERT INTO MessageLocationTable (message_id, folder_id, ordering) VALUES (?, ?, ?)");
        query.bind_int64(0, row.message_id);
        query.bind_int64(1, row.folder_id);
        query.bind_int64(2, row.ordering);
        
        int64 id = yield query.execute_insert_async(cancellable);
        locked.set_commit_required();
        
        yield release_lock_async(transaction, locked, cancellable);
        
        return id;
    }
    
    /**
     * low is one-based.  If count is -1, all messages starting at low are returned.
     */
    public async Gee.List<MessageLocationRow>? list_async(Transaction? transaction,
        int64 folder_id, int low, int count, Cancellable? cancellable) throws Error {
        assert(low >= 1);
        assert(count >= 0 || count == -1);
        
        Transaction locked = yield obtain_lock_async(transaction, "MessageLocationTable.list_async",
            cancellable);
        
        SQLHeavy.Query query;
        if (count >= 0) {
            query = locked.prepare(
                "SELECT id, message_id, ordering FROM MessageLocationTable WHERE folder_id = ? "
                + "ORDER BY ordering LIMIT ? OFFSET ?");
            query.bind_int64(0, folder_id);
            query.bind_int(1, count);
            query.bind_int(2, low - 1);
        } else {
            // count == -1
            query = locked.prepare(
                "SELECT id, message_id, ordering FROM MessageLocationTable WHERE folder_id = ? "
                + "ORDER BY ordering OFFSET ?");
            query.bind_int64(0, folder_id);
            query.bind_int(1, low - 1);
        }
        
        SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
        if (results.finished)
            return null;
        
        Gee.List<MessageLocationRow> list = new Gee.ArrayList<MessageLocationRow>();
        int position = low;
        do {
            list.add(new MessageLocationRow(this, results.fetch_int64(0), results.fetch_int64(1),
                folder_id, results.fetch_int64(2), position++));
            
            yield results.next_async(cancellable);
        } while (!results.finished);
        
        return list;
    }
    
    /**
     * All positions are one-based.
     */
    public async Gee.List<MessageLocationRow>? list_sparse_async(Transaction? transaction,
        int64 folder_id, int[] by_position, Cancellable? cancellable) throws Error {
        Transaction locked = yield obtain_lock_async(transaction, "MessageLocationTable.list_sparse_async",
            cancellable);
        
        // reuse the query for each iteration
        SQLHeavy.Query query = locked.prepare(
            "SELECT id, message_id, ordering FROM MessageLocationTable WHERE folder_id = ? "
            + "ORDER BY ordering LIMIT 1 OFFSET ?");
        
        Gee.List<MessageLocationRow> list = new Gee.ArrayList<MessageLocationRow>();
        foreach (int position in by_position) {
            assert(position >= 1);
            
            query.bind_int64(0, folder_id);
            query.bind_int(1, position - 1);
            
            SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
            if (results.finished)
                continue;
            
            list.add(new MessageLocationRow(this, results.fetch_int64(0), results.fetch_int64(1),
                folder_id, results.fetch_int64(2), position));
            
            query.clear();
        }
        
        return (list.size > 0) ? list : null;
    }
    
    public async Gee.List<MessageLocationRow>? list_ordering_async(Transaction? transaction,
        int64 folder_id, int64 low_ordering, int64 high_ordering, Cancellable? cancellable)
        throws Error {
        Transaction locked = yield obtain_lock_async(transaction, "MessageLocationTable.list_ordering_async",
            cancellable);
        
        assert(low_ordering >= 0 || low_ordering == -1);
        assert(high_ordering >= 0 || high_ordering == -1);
        
        SQLHeavy.Query query;
        if (high_ordering != -1 && low_ordering != -1) {
            query = locked.prepare(
                "SELECT id, message_id, ordering FROM MessageLocationTable WHERE folder_id = ? "
                + "AND ordering >= ? AND ordering <= ? ORDER BY ordering ASC");
            query.bind_int64(0, folder_id);
            query.bind_int64(1, low_ordering);
            query.bind_int64(2, high_ordering);
        } else if (high_ordering == -1) {
            query = locked.prepare(
                "SELECT id, message_id, ordering FROM MessageLocationTable WHERE folder_id = ? "
                + "AND ordering >= ? ORDER BY ordering ASC");
            query.bind_int64(0, folder_id);
            query.bind_int64(1, low_ordering);
        } else {
            assert(low_ordering == -1);
            query = locked.prepare(
                "SELECT id, message_id, ordering FROM MessageLocationTable WHERE folder_id = ? "
                + "AND ordering <= ? ORDER BY ordering ASC");
            query.bind_int64(0, folder_id);
            query.bind_int64(1, high_ordering);
        }
        
        SQLHeavy.QueryResult result = yield query.execute_async(cancellable);
        if (result.finished)
            return null;
        
        Gee.List<MessageLocationRow>? list = new Gee.ArrayList<MessageLocationRow>();
        do {
            list.add(new MessageLocationRow(this, result.fetch_int64(0), result.fetch_int64(1),
                folder_id, result.fetch_int64(2), -1));
            
            yield result.next_async(cancellable);
        } while (!result.finished);
        
        return (list.size > 0) ? list : null;
    }
    
    /**
     * position is one-based.
     */
    public async MessageLocationRow? fetch_async(Transaction transaction, int64 folder_id,
        int position, Cancellable? cancellable) throws Error {
        assert(position >= 1);
        
        Transaction locked = yield obtain_lock_async(transaction, "MessageLocationTable.fetch_async",
            cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "SELECT id, message_id, ordering FROM MessageLocationTable WHERE folder_id = ? "
            + "ORDER BY ordering LIMIT 1 OFFSET ?");
        query.bind_int64(0, folder_id);
        query.bind_int(1, position - 1);
        
        SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
        if (results.finished)
            return null;
        
        return new MessageLocationRow(this, results.fetch_int64(0), results.fetch_int64(1), folder_id,
            results.fetch_int64(2), position);
    }
    
    public async MessageLocationRow? fetch_by_ordering_async(Transaction? transaction,
        int64 folder_id, int64 ordering, Cancellable? cancellable) throws Error {
        Transaction locked = yield obtain_lock_async(transaction, "MessageLocationTable.fetch_by_ordering_async",
            cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "SELECT id, message_id FROM MessageLocationTable WHERE folder_id = ? AND ordering = ? ");
        query.bind_int64(0, folder_id);
        query.bind_int64(1, ordering);
        
        SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
        if (results.finished)
            return null;
        
        return new MessageLocationRow(this, results.fetch_int64(0), results.fetch_int64(1),
            folder_id, ordering, -1);
    }
    
    public async int fetch_position_async(Transaction? transaction, int64 id, 
        int64 folder_id, Cancellable? cancellable) throws Error {
        Transaction locked = yield obtain_lock_async(transaction, "MessageLocationTable.fetch_position_async",
            cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "SELECT id FROM MessageLocationTable WHERE folder_id = ? ORDER BY ordering");
        query.bind_int64(0, folder_id);
        
        SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
        
        int position = 1;
        while (!results.finished) {
            if (results.fetch_int64(0) == id)
                return position;
            
            yield results.next_async(cancellable);
            position++;
        }
        
        // not found
        return -1;
    }
    
    public async int fetch_message_position_async(Transaction? transaction, int64 message_id,
        int64 folder_id, Cancellable? cancellable) throws Error {
        Transaction locked = yield obtain_lock_async(transaction,
            "MessageLocationTable.fetch_message_position_async", cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "SELECT message_id FROM MessageLocationTable WHERE folder_id=? ORDER BY ordering");
        query.bind_int64(0, folder_id);
        
        SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
        
        int position = 1;
        while (!results.finished) {
            if (results.fetch_int64(0) == message_id)
                return position;
            
            yield results.next_async(cancellable);
            position++;
        }
        
        // not found
        return -1;
    }
    
    public async int fetch_count_for_folder_async(Transaction? transaction, 
        int64 folder_id, Cancellable? cancellable) throws Error {
        Transaction locked = yield obtain_lock_async(transaction,
            "MessageLocationTable.fetch_count_for_folder_async", cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "SELECT COUNT(*) FROM MessageLocationTable WHERE folder_id = ?");
        query.bind_int64(0, folder_id);
        
        SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
        
        return (!results.finished) ? results.fetch_int(0) : 0;
    }
    
    /**
     * Find a row based on its ordering value in the folder.
     */
    public async bool does_ordering_exist_async(Transaction? transaction, int64 folder_id,
        int64 ordering, out int64 message_id, Cancellable? cancellable) throws Error {
        message_id = Row.INVALID_ID;
        
        Transaction locked = yield obtain_lock_async(transaction,
            "MessageLocationTable.does_ordering_exist_async", cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "SELECT message_id FROM MessageLocationTable WHERE folder_id = ? AND ordering = ?");
        query.bind_int64(0, folder_id);
        query.bind_int64(1, ordering);
        
        SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
        if (results.finished)
            return false;
        
        message_id = results.fetch_int64(0);
        
        return true;
    }
    
    public async int64 get_earliest_ordering_async(Transaction? transaction, int64 folder_id,
        Cancellable? cancellable) throws Error {
        Transaction locked = yield obtain_lock_async(transaction,
            "MessageLocationTable.get_earliest_ordering_async", cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "SELECT MIN(ordering) FROM MessageLocationTable WHERE folder_id = ?");
        query.bind_int64(0, folder_id);
        
        SQLHeavy.QueryResult result = yield query.execute_async(cancellable);
        
        return (!result.finished) ? result.fetch_int64(0) : -1;
    }
    
    public async bool remove_by_ordering_async(Transaction? transaction, int64 folder_id,
        int64 ordering, Cancellable? cancellable) throws Error {
        Transaction locked = yield obtain_lock_async(transaction,
            "MessageLocationTable.remove_by_ordering_async", cancellable);
        
        SQLHeavy.Query query = locked.prepare(
            "SELECT id FROM MessageLocationTable WHERE folder_id=? AND ordering=?");
        query.bind_int64(0, folder_id);
        query.bind_int64(1, ordering);
        
        SQLHeavy.QueryResult results = yield query.execute_async(cancellable);
        if (results.finished)
            return false;
        
        query = locked.prepare("DELETE FROM MessageLocationTable WHERE id=?");
        query.bind_int64(0, results.fetch_int(0));
        
        yield query.execute_async(cancellable);
        locked.set_commit_required();
        
        yield release_lock_async(transaction, locked, cancellable);
        
        return true;
    }
}

