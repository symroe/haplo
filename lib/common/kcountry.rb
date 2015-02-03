# coding: utf-8

# Haplo Platform                                     http://haplo.org
# (c) ONEIS Ltd 2006 - 2015                    http://www.oneis.co.uk
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.


# ITU-T assigns code 379 to Vatican City. However, Vatican City is included in the Italian telephone numbering plan and uses the Italian country code 39, followed by 06 (for Rome) and 698.

module KCountry

  COUNTRY_BY_ISO = Hash.new
  COUNTRY_BY_PHONE_CODE = Hash.new

  Country = Struct.new(:is_iso, :iso_code, :phone_code, :international_dial, :trunk_code, :name)

  COUNTRIES = [
      Country.new(true, 'AD', '376', '00', '0', 'Andorra'),
      Country.new(true, 'AX', nil, nil, nil, 'Åland Islands'),
      Country.new(true, 'AF', '93', '00', '0', 'Afghanistan'),
      Country.new(true, 'AL', '355', '00', '0', 'Albania'),
      Country.new(true, 'DZ', '213', '00', '0', 'Algeria'),
      Country.new(true, 'AS', '1', '011', '1', 'American Samoa'),
      Country.new(true, 'AO', '244', '00', '', 'Angola'),
      Country.new(true, 'AI', '1', '011', '1', 'Anguilla'),
      Country.new(true, 'AQ', nil, nil, nil, 'Antarctica'),
      Country.new(true, 'AG', '1', '011', '1', 'Antigua and Barbuda'),
      Country.new(true, 'AR', '54', '00', '0', 'Argentina'),
      Country.new(true, 'AM', '374', '00', '0', 'Armenia'),
      Country.new(true, 'AW', '297', '00', '0', 'Aruba'),
      Country.new(false, '247', '247', '00', '0', 'Ascension'),
      Country.new(true, 'AU', '61', '0011', '0', 'Australia'),
      Country.new(true, 'AT', '43', '00', '0', 'Austria'),
      Country.new(true, 'AZ', '994', '00', '0', 'Azerbaijan'),
      Country.new(true, 'BS', '1', '011', '1', 'Bahamas'),
      Country.new(true, 'BH', '973', '00', '', 'Bahrain'),
      Country.new(true, 'BD', '880', '00', '0', 'Bangladesh'),
      Country.new(true, 'BB', '1', '011', '1', 'Barbados'),
      Country.new(true, 'BY', '375', '8 Pause 10', '8', 'Belarus'),
      Country.new(true, 'BE', '32', '00', '0', 'Belgium'),
      Country.new(true, 'BZ', '501', '00', '', 'Belize'),
      Country.new(true, 'BJ', '229', '00', '', 'Benin'),
      Country.new(true, 'BM', '1', '011', '1', 'Bermuda'),
      Country.new(true, 'BT', '975', '00', '', 'Bhutan'),
      Country.new(true, 'BO', '591', '00', '0', 'Bolivia'),
      Country.new(true, 'BA', '387', '00', '0', 'Bosnia and Herzegovina'),
      Country.new(true, 'BW', '267', '00', '', 'Botswana'),
      Country.new(true, 'BV', nil, nil, nil, 'Bouvet Island'),
      Country.new(true, 'BR', '55', '00', '0', 'Brazil'),
      Country.new(true, 'IO', nil, nil, nil, 'British Indian Ocean Territory'),
      Country.new(true, 'BN', '673', '00', '', 'Brunei Darussalam'),
      Country.new(true, 'BG', '359', '00', '0', 'Bulgaria'),
      Country.new(true, 'BF', '226', '00', '', 'Burkina Faso'),
      Country.new(true, 'BI', '257', '00', '', 'Burundi'),
      Country.new(true, 'KH', '855', '001, 007', '0', 'Cambodia'),
      Country.new(true, 'CM', '237', '00', '0', 'Cameroon'),
      Country.new(true, 'CA', '1', '011', '1', 'Canada'),
      Country.new(true, 'CV', '238', '0', '0', 'Cape Verde'),
      Country.new(true, 'KY', '1', '011', '1', 'Cayman Islands'),
      Country.new(true, 'CF', '236', '00', '0', 'Central African Republic'),
      Country.new(true, 'TD', '235', '15', '0', 'Chad'),
      Country.new(true, 'CL', '56', '???', '0', 'Chile'),
      Country.new(true, 'CN', '86', '00', '0', 'China'),
      Country.new(true, 'CX', nil, nil, nil, 'Christmas Island'),
      Country.new(true, 'CC', nil, nil, nil, 'Cocos (Keeling) Islands'),
      Country.new(true, 'CO', '57', '009, 007, 005', '0', 'Colombia'),
      Country.new(true, 'KM', '269', '00', '0', 'Comoros'),
      Country.new(true, 'CG', '242', '00', '0', 'Congo'),
      Country.new(true, 'CD', '243', '00', '0', 'Congo, The Democratic Republic of The'),
      Country.new(true, 'CK', '682', '00', '0', 'Cook Islands'),
      Country.new(true, 'CR', '506', '00', '0', 'Costa Rica'),
      Country.new(true, 'HR', '385', '00', '0', 'Croatia'),
      Country.new(true, 'CU', '53', '119', '0', 'Cuba'),
      Country.new(true, 'CY', '357', '00', '0', 'Cyprus'),
      Country.new(true, 'CZ', '420', '00', '0', 'Czech Republic'),
      Country.new(true, 'CI', '225', '00', '0', "Côte d'Ivoire"),
      Country.new(true, 'DK', '45', '00', '0', 'Denmark'),
      Country.new(false, '246', '246', '00', '0', 'Diego Garcia'),
      Country.new(true, 'DJ', '253', '00', '0', 'Djibouti'),
      Country.new(true, 'DM', '1', '011', '1', 'Dominica'),
      Country.new(true, 'DO', '1', '011', '1', 'Dominican Republic'),
      Country.new(true, 'EC', '593', '00', '0', 'Ecuador'),
      Country.new(true, 'EG', '20', '00', '0', 'Egypt'),
      Country.new(true, 'SV', '503', '00', '0', 'El Salvador'),
      Country.new(true, 'GQ', '240', '00', '0', 'Equatorial Guinea'),
      Country.new(true, 'ER', '291', '00', '0', 'Eritrea'),
      Country.new(true, 'EE', '372', '00', '0', 'Estonia'),
      Country.new(true, 'ET', '251', '00', '0', 'Ethiopia'),
      Country.new(true, 'FK', '500', '00', '0', 'Falkland Islands (Malvinas)'),
      Country.new(true, 'FO', '298', '00', '0', 'Faroe Islands'),
      Country.new(true, 'FJ', '679', '00', '0', 'Fiji'),
      Country.new(true, 'FI', '358', '00', '0', 'Finland'),
      Country.new(true, 'FR', '33', '00', '0', 'France'),
      Country.new(true, 'GF', '594', '00', '0', 'French Guiana'),
      Country.new(true, 'PF', '689', '00', '0', 'French Polynesia'),
      Country.new(true, 'TF', nil, nil, nil, 'French Southern Territories'),
      Country.new(true, 'GA', '241', '00', '0', 'Gabon'),
      Country.new(true, 'GM', '220', '00', '0', 'Gambia'),
      Country.new(true, 'GE', '995', '8 Pause 10', '8', 'Georgia'),
      Country.new(true, 'DE', '49', '00', '0', 'Germany'),
      Country.new(true, 'GH', '233', '00', '0', 'Ghana'),
      Country.new(true, 'GI', '350', '00', '', 'Gibraltar'),
      Country.new(true, 'GR', '30', '00', '0', 'Greece'),
      Country.new(true, 'GL', '299', '00', '', 'Greenland'),
      Country.new(true, 'GD', '1', '011', '1', 'Grenada'),
      Country.new(true, 'GP', '590', '00', '0', 'Guadeloupe'),
      Country.new(true, 'GU', '1', '011', '1', 'Guam'),
      Country.new(true, 'GT', '502', '00', '0', 'Guatemala'),
      Country.new(true, 'GG', nil, nil, nil, 'Guernsey'),
      Country.new(true, 'GN', '224', '00', '0', 'Guinea'),
      Country.new(true, 'GW', '245', '00', '0', 'Guinea-Bissau'),
      Country.new(true, 'GY', '592', '001', '0', 'Guyana'),
      Country.new(true, 'HT', '509', '00', '0', 'Haiti'),
      Country.new(true, 'HM', nil, nil, nil, 'Heard Island and Mcdonald Islands'),
      Country.new(true, 'HN', '504', '00', '0', 'Honduras'),
      Country.new(true, 'HK', '852', '001', '', 'Hong Kong'),
      Country.new(true, 'HU', '36', '00', '0', 'Hungary'),
      Country.new(true, 'IS', '354', '00', '0', 'Iceland'),
      Country.new(true, 'IN', '91', '00', '0', 'India'),
      Country.new(true, 'ID', '62', '001, 008', '0', 'Indonesia'),
      Country.new(true, 'IR', '98', '00', '0', 'Iran, Islamic Republic of'),
      Country.new(true, 'IQ', '964', '00', '0', 'Iraq'),
      Country.new(true, 'IE', '353', '00', '0', 'Ireland'),
      Country.new(true, 'IM', nil, nil, nil, 'Isle of Man'),
      Country.new(true, 'IL', '972', '00, 012, 013, 014', '0', 'Israel'),
      Country.new(true, 'IT', '39', '00', '0', 'Italy'),
      Country.new(true, 'JM', '1', '011', '1', 'Jamaica'),
      Country.new(true, 'JP', '81', '010', '0', 'Japan'),
      Country.new(true, 'JE', nil, nil, nil, 'Jersey'),
      Country.new(true, 'JO', '962', '00', '0', 'Jordan'),
      Country.new(true, 'KZ', '7', '8 Pause 10', '8', 'Kazakhstan'),
      Country.new(true, 'KE', '254', '000', '0', 'Kenya'),
      Country.new(true, 'KI', '686', '00', '0', 'Kiribati'),
      Country.new(true, 'KP', '850', '99', '', "Korea, Democratic People's Republic of"),
      Country.new(true, 'KR', '82', '001, 002', '0', 'Korea, Republic of'),
      Country.new(true, 'XK', '381', '00', '0', 'Kosovo, Republic of'),
      Country.new(true, 'KW', '965', '00', '0', 'Kuwait'),
      Country.new(true, 'KG', '996', '00', '0', 'Kyrgyzstan'),
      Country.new(true, 'LA', '856', '00', '0', "Lao People's Democratic Republic"),
      Country.new(true, 'LV', '371', '00', '0', 'Latvia'),
      Country.new(true, 'LB', '961', '00', '0', 'Lebanon'),
      Country.new(true, 'LS', '266', '00', '0', 'Lesotho'),
      Country.new(true, 'LR', '231', '00', '0', 'Liberia'),
      Country.new(true, 'LY', '218', '00', '0', 'Libya'),
      Country.new(true, 'LI', '423', '00', '0', 'Liechtenstein'),
      Country.new(true, 'LT', '370', '00', '0', 'Lithuania'),
      Country.new(true, 'LU', '352', '00', '0', 'Luxembourg'),
      Country.new(true, 'MO', '853', '00', '', 'Macao'),
      Country.new(true, 'MK', '389', '00', '0', 'Macedonia, The Former Yugoslav Republic of'),
      Country.new(true, 'MG', '261', '00', '0', 'Madagascar'),
      Country.new(true, 'MW', '265', '00', '0', 'Malawi'),
      Country.new(true, 'MY', '60', '00', '0', 'Malaysia'),
      Country.new(true, 'MV', '960', '00', '0', 'Maldives'),
      Country.new(true, 'ML', '223', '00', '0', 'Mali'),
      Country.new(true, 'MT', '356', '00', '0', 'Malta'),
      Country.new(true, 'MH', '692', '011', '0', 'Marshall Islands'),
      Country.new(true, 'MQ', '596', '00', '0', 'Martinique'),
      Country.new(true, 'MR', '222', '00', '0', 'Mauritania'),
      Country.new(true, 'MU', '230', '00', '0', 'Mauritius'),
      Country.new(true, 'YT', '269', '00', '0', 'Mayotte'),
      Country.new(true, 'MX', '52', '00', '0', 'Mexico'),
      Country.new(true, 'FM', '691', '011', '0', 'Micronesia, Federated States of'),
      Country.new(true, 'MD', '373', '00', '0', 'Moldova, Republic of'),
      Country.new(true, 'MC', '377', '00', '0', 'Monaco'),
      Country.new(true, 'MN', '976', '001', '0', 'Mongolia'),
      Country.new(true, 'ME', '382', '00', '0', 'Montenegro'),
      Country.new(true, 'MS', '1', '011', '1', 'Montserrat'),
      Country.new(true, 'MA', '212', '00', '0', 'Morocco'),
      Country.new(true, 'MZ', '258', '00', '0', 'Mozambique'),
      Country.new(true, 'MM', '95', '00', '0', 'Myanmar'),
      Country.new(true, 'NA', '264', '00', '0', 'Namibia'),
      Country.new(true, 'NR', '674', '00', '0', 'Nauru'),
      Country.new(true, 'NP', '977', '00', '0', 'Nepal'),
      Country.new(true, 'NL', '31', '00', '0', 'Netherlands'),
      Country.new(true, 'AN', nil, nil, nil, 'Netherlands Antilles'),
      Country.new(true, 'NC', '687', '00', '0', 'New Caledonia'),
      Country.new(true, 'NZ', '64', '00', '0', 'New Zealand'),
      Country.new(true, 'NI', '505', '00', '0', 'Nicaragua'),
      Country.new(true, 'NE', '227', '00', '0', 'Niger'),
      Country.new(true, 'NG', '234', '009', '0', 'Nigeria'),
      Country.new(true, 'NU', '683', '00', '0', 'Niue'),
      Country.new(true, 'NF', nil, nil, nil, 'Norfolk Island'),
      Country.new(true, 'MP', '1', '011', '1', 'Northern Mariana Islands'),
      Country.new(true, 'NO', '47', '00', '0', 'Norway'),
      Country.new(true, 'OM', '968', '00', '0', 'Oman'),
      Country.new(true, 'PK', '92', '00', '0', 'Pakistan'),
      Country.new(true, 'PW', '680', '011', '0', 'Palau'),
      Country.new(true, 'PS', nil, nil, nil, 'Palestinian Territory, Occupied'),
      Country.new(true, 'PA', '507', '00', '0', 'Panama'),
      Country.new(true, 'PG', '675', '05', '0', 'Papua New Guinea'),
      Country.new(true, 'PY', '595', '00', '0', 'Paraguay'),
      Country.new(true, 'PE', '51', '00', '0', 'Peru'),
      Country.new(true, 'PH', '63', '00', '0', 'Philippines'),
      Country.new(true, 'PN', nil, nil, nil, 'Pitcairn'),
      Country.new(true, 'PL', '48', '00', '0', 'Poland'),
      Country.new(true, 'PT', '351', '00', '0', 'Portugal'),
      Country.new(true, 'PR', '1', '011', '1', 'Puerto Rico'),
      Country.new(true, 'QA', '974', '00', '0', 'Qatar'),
      Country.new(true, 'RO', '40', '00', '0', 'Romania'),
      Country.new(true, 'RU', '7', '8 Pause 10', '8', 'Russian Federation'),
      Country.new(true, 'RW', '250', '00', '0', 'Rwanda'),
      Country.new(true, 'RE', '262', '00', '0', 'Réunion'),
      Country.new(true, 'BL', nil, nil, nil, 'Saint Barthélemy'),
      Country.new(true, 'SH', '290', '00', '0', 'Saint Helena'),
      Country.new(true, 'KN', '1', '011', '1', 'Saint Kitts and Nevis'),
      Country.new(true, 'LC', '1', '011', '1', 'Saint Lucia'),
      Country.new(true, 'MF', nil, nil, nil, 'Saint Martin'),
      Country.new(true, 'PM', '508', '00', '0', 'Saint Pierre and Miquelon'),
      Country.new(true, 'VC', '1', '011', '1', 'Saint Vincent and The Grenadines'),
      Country.new(true, 'WS', '685', '0', '0', 'Samoa'),
      Country.new(true, 'SM', '378', '00', '0', 'San Marino'),
      Country.new(true, 'ST', '239', '00', '0', 'Sao Tome and Principe'),
      Country.new(true, 'SA', '966', '00', '0', 'Saudi Arabia'),
      Country.new(true, 'SN', '221', '00', '0', 'Senegal'),
      Country.new(true, 'RS', '381', '00', '0', 'Serbia'),
      Country.new(true, 'SC', '248', '00', '0', 'Seychelles'),
      Country.new(true, 'SL', '232', '00', '0', 'Sierra Leone'),
      Country.new(true, 'SG', '65', '001, 008', '0', 'Singapore'),
      Country.new(true, 'SK', '421', '00', '0', 'Slovakia'),
      Country.new(true, 'SI', '386', '00', '0', 'Slovenia'),
      Country.new(true, 'SB', '677', '00', '0', 'Solomon Islands'),
      Country.new(true, 'SO', '252', '00', '0', 'Somalia'),
      Country.new(true, 'ZA', '27', '00', '0', 'South Africa'),
      Country.new(true, 'GS', nil, nil, nil, 'South Georgia and The South Sandwich Islands'),
      Country.new(true, 'ES', '34', '00', '0', 'Spain'),
      Country.new(true, 'LK', '94', '00', '0', 'Sri Lanka'),
      Country.new(true, 'SD', '249', '00', '0', 'Sudan'),
      Country.new(true, 'SR', '597', '00', '0', 'Suriname'),
      Country.new(true, 'SJ', nil, nil, nil, 'Svalbard and Jan Mayen'),
      Country.new(true, 'SZ', '268', '00', '0', 'Swaziland'),
      Country.new(true, 'SE', '46', '00', '0', 'Sweden'),
      Country.new(true, 'CH', '41', '00', '0', 'Switzerland'),
      Country.new(true, 'SY', '963', '00', '0', 'Syrian Arab Republic'),
      Country.new(true, 'TW', nil, nil, nil, 'Taiwan, Province of China'),
      Country.new(true, 'TJ', '992', '8 Pause 10', '8', 'Tajikistan'),
      Country.new(true, 'TZ', '255', '000', '0', 'Tanzania, United Republic of'),
      Country.new(true, 'TH', '66', '001', '0', 'Thailand'),
      Country.new(true, 'TL', '670', '00', '0', 'Timor-Leste'),
      Country.new(true, 'TG', '228', '00', '0', 'Togo'),
      Country.new(true, 'TK', '690', '00', '0', 'Tokelau'),
      Country.new(true, 'TO', '676', '00', '0', 'Tonga'),
      Country.new(true, 'TT', '1', '011', '1', 'Trinidad and Tobago'),
      Country.new(true, 'TN', '216', '00', '0', 'Tunisia'),
      Country.new(true, 'TR', '90', '00', '0', 'Turkey'),
      Country.new(true, 'TM', '993', '8 Pause 10', '8', 'Turkmenistan'),
      Country.new(true, 'TC', '1', '011', '0', 'Turks and Caicos Islands'),
      Country.new(true, 'TV', '688', '00', '0', 'Tuvalu'),
      Country.new(true, 'UG', '256', '000', '0', 'Uganda'),
      Country.new(true, 'UA', '380', '8 Pause 10', '8', 'Ukraine'),
      Country.new(true, 'AE', '971', '00', '0', 'United Arab Emirates'),
      Country.new(true, 'GB', '44', '00', '0', 'United Kingdom'),
      Country.new(true, 'US', '1', '011', '1', 'United States'),
      Country.new(true, 'UM', nil, nil, nil, 'United States Minor Outlying Islands'),
      Country.new(true, 'UY', '598', '00', '0', 'Uruguay'),
      Country.new(true, 'UZ', '998', '8 Pause 10', '8', 'Uzbekistan'),
      Country.new(true, 'VU', '678', '00', '0', 'Vanuatu'),
      Country.new(true, 'VA', '39', '00', '0', 'Vatican City State (Holy See)'),
      Country.new(true, 'VE', '58', '00', '0', 'Venezuela'),
      Country.new(true, 'VN', '84', '00', '0', 'Viet Nam'),
      Country.new(true, 'VG', '1', '011', '1', 'Virgin Islands, British'),
      Country.new(true, 'VI', '1', '011', '1', 'Virgin Islands, U.S.'),
      Country.new(true, 'WF', '681', '00', '0', 'Wallis and Futuna'),
      Country.new(true, 'EH', nil, nil, nil, 'Western Sahara'),
      Country.new(true, 'YE', '967', '00', '0', 'Yemen'),
      Country.new(true, 'ZM', '260', '00', '0', 'Zambia'),
      Country.new(true, 'ZW', '263', '00', '0', 'Zimbabwe')
    ]
  COUNTRIES.freeze

  # Fill other structures
  COUNTRIES.each do |country|
    country.freeze
    COUNTRY_BY_ISO[country.iso_code] = country
    COUNTRY_BY_PHONE_CODE[country.phone_code] = country if country.phone_code != nil
  end

  # --------------------------------------------------------------------------------------------------------------------
  # Generate Javascript info.
  # Manually copied to keditor.js
  # script/runner "KCountry.keditor_javascript_definitions()"
  def self.keditor_javascript_definitions
    countries = Array.new
    COUNTRIES.each do |c|
      countries << [c.iso_code,c.name,c.phone_code]
    end
    puts "var q__COUNTRIES = #{countries.to_json};\n"
  end

end
