/* Copyright © 2014 Christopher James Halse Rogers <raof@ubuntu.com>
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

/**
 * A representation of the IMAP AUTHENTICATE command.
 *
 * See [[http://tools.ietf.org/search/rfc3501#section-6.2.2]]
 */

public class Geary.Imap.AuthenticateCommand : Command {
    public const string NAME = "authenticate";
    
    public AuthenticateCommand(string method, string data) {
        base (NAME, {method, data});
     }

    public override string to_string() {
        return "%s %s %s <client secret>".printf(tag.to_string(), name, args[0]);
    }
}

public class Geary.Imap.EmptySaslResponse : Command {
    public const string NAME = "fix the engine instead";

    public EmptySaslResponse() {
        base(NAME);
    }

    public override void serialize(Serializer ser, Tag tag) throws Error {
        ser.push_ascii('\r');
        ser.push_ascii('\n');
    }

}
