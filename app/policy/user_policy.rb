# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

#
# The UserPolicy object (available as user.policy) decides what a user is authorised to do.
# See other policies defined in app/policy/user_policy/*.rb
#
# Note that caching is problematic, as invalidation is a bit hard given all the objects floating around.
#

class UserPolicy

  def initialize(user)
    @user = user
    @policy_bitmask = user.policy_bitmask()
  end

  # ----------------------------------------------------------------------------------------------
  #  Basic Policies

  # Make all the basic can_policy? functions
  self.module_eval(KPolicyRegistry.entries.map do |e|
    bit = 1 << e.bitfield_index
    "def can_#{e.symbol}?; (@policy_bitmask & #{bit}) == #{bit}; end"
  end .join("\n"))

  # Alias/inverse for readability
  alias is_not_anonymous? can_not_anonymous?
  def   is_anonymous? ; !(can_not_anonymous?); end
  alias is_otp_token_required? can_require_token?

  # Check policy given a bitmask
  def check_policy_bitmask(bitmask)
    (@policy_bitmask & bitmask) == bitmask
  end

end
