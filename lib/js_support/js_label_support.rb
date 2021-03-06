# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# Provide utility functions to labelling JavaScript objects

module JSLabelStatementSupport

  # JSON is untrusted, as it comes from the JavaScript runtime
  def self.createFromBuilder(json)
    decoded_json = JSON.parse(json)
    # load_untrusted_rules_from_javascript is checks the data carefully
    rule_list = PermissionRule::RuleList.new
    rule_list.load_untrusted_rules_from_javascript(decoded_json)
    rule_list.to_label_statements
  end

  def self.combine(a, b, operation)
    KLabelStatements.combine(a, b, operation)
  end

end

Java::ComOneisJsinterface::KLabelStatements.setRubyInterface(JSLabelStatementSupport)

# ------------------------------------------------------------------------------------------

module JSLabelListSupport

  def self.constructLabelList(labels)
    KLabelList.new(labels.to_a)
  end

  def self.filterToLabelsOfType(labels, types)
    return [] if labels.empty? || types.empty?
    KObjectStore.filter_id_list_to_ids_of_type(labels, types)
  end

end

Java::ComOneisJsinterface::KLabelList.setRubyInterface(JSLabelListSupport)

# ------------------------------------------------------------------------------------------

module JSLabelChangesSupport

  def self.constructLabelChanges(add, remove)
    KLabelChanges.new(add.to_a, remove.to_a)
  end

  def self.addParentsToList(labels)
    labels.map { |id| KObjectStore.full_obj_id_path(KObjRef.new(id)) } .flatten.sort.uniq
  end

end

Java::ComOneisJsinterface::KLabelChanges.setRubyInterface(JSLabelChangesSupport)
