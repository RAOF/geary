/* -*- Mode: vala; indent-tabs-mode: nil; c-basic-offset: 4; tab-width: 8 -*-  */
/*
 * google-account.vala
 * Copyright © 2014 Christopher James Halse Rogers <chris@cooperteam.net>
 *
 * Geary is free software: you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published
 * by the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 * 
 * Geary is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.";
 */

public class GoogleAccount /*: BaseObject*/ {

    // Constructor
        public GoogleAccount () {
            account_manager = new Ag.Manager.for_service_type("mail");
            GLib.List<Ag.AccountService> services = account_manager.get_account_services();
            services.foreach((entry) => { var account = entry.get_account();
                var auth = entry.get_auth_data();
                stdout.puts(account.get_display_name());
                stdout.puts(" (");
                stdout.puts(account.get_provider_name());
                stdout.puts("): ");
                stdout.puts(account.get_enabled() ? "enabled" : "disabled");
                stdout.putc('\n');
                stdout.puts("\tMechanism: ");
                stdout.puts(auth.get_mechanism());
                stdout.puts("\n\tMethod: ");
                stdout.puts(auth.get_method());
                stdout.puts("\n\tLogin Data: ");
                stdout.puts(auth.get_login_parameters(null).print(true));
                stdout.putc('\n');
            });
        }

    private Ag.Manager account_manager; 
}

int main (string[] args)
{
    var account = new GoogleAccount();
    return 0;
}