// Ported from fake 2.10.0: src/faker/impls/company.rs, src/faker/impls/name.rs (LastName) and src/locales/mod.rs (the English data they use)
// Original code Copyright (c) 2018 cksac, licensed under MIT OR Apache-2.0.
// Modified: translated from Rust to Haxe for Ceramic (only what gpui-kit's story gallery uses). See NOTICE.md.
package story;

/**
 * The few generators of the `fake` crate the story gallery uses (random
 * company names and industries, random floats in a range), with the crate's
 * English data. They draw from Haxe's `Math.random` (the crate uses
 * `rand`'s thread generator, seeded by the OS): the values are random on
 * both sides and never match.
 */
class Fake {

    /** `(start..end).fake::<f64>()`: uniform in `[start, end)`. */
    public static function float(start:Float, end:Float):Float {
        return start + Math.random() * (end - start);
    }

    /** `rand::random::<usize>() modulo len`. */
    public static function index(len:Int):Int {
        return Std.int(Math.random() * len);
    }

    static function choose(items:Array<String>):String {
        return items[index(items.length)];
    }

    /** `LastName().fake::<&str>()`. */
    public static function lastName():String {
        return choose(NAME_LAST_NAME);
    }

    /** `CompanySuffix().fake::<&str>()`. */
    public static function companySuffix():String {
        return choose(COMPANY_SUFFIX);
    }

    /** `CompanyName().fake::<String>()`. */
    public static function companyName():String {
        final tpl = choose(COMPANY_NAME_TPLS);
        final name1 = lastName();
        final name2 = lastName();
        final suffix = companySuffix();
        return StringTools.replace(StringTools.replace(StringTools.replace(tpl, '{Name_1}', name1), '{Name_2}', name2), '{Suffix}', suffix);
    }

    /** `Industry().fake::<String>()`. */
    public static function industry():String {
        return choose(COMPANY_INDUSTRY);
    }

    static final COMPANY_SUFFIX:Array<String> = [
        'Inc', 'and Sons', 'LLC', 'Group',
    ];

    static final COMPANY_NAME_TPLS:Array<String> = [
        '{Name_1} {Suffix}', '{Name_1} and {Name_2} {Suffix}',
    ];

    static final COMPANY_INDUSTRY:Array<String> = [
        'Defense & Space', 'Computer Hardware', 'Computer Software', 'Computer Networking', 'Internet', 'Semiconductors',
        'Telecommunications', 'Law Practice', 'Legal Services', 'Management Consulting', 'Biotechnology', 'Medical Practice',
        'Hospital & Health Care', 'Pharmaceuticals', 'Veterinary', 'Medical Devices', 'Cosmetics', 'Apparel & Fashion', 'Sporting Goods',
        'Tobacco', 'Supermarkets', 'Food Production', 'Consumer Electronics', 'Consumer Goods', 'Furniture', 'Retail', 'Entertainment',
        'Gambling & Casinos', 'Leisure, Travel & Tourism', 'Hospitality', 'Restaurants', 'Sports', 'Food & Beverages',
        'Motion Pictures and Film', 'Broadcast Media', 'Museums and Institutions', 'Fine Art', 'Performing Arts',
        'Recreational Facilities and Services', 'Banking', 'Insurance', 'Financial Services', 'Real Estate', 'Investment Banking',
        'Investment Management', 'Accounting', 'Construction', 'Building Materials', 'Architecture & Planning', 'Civil Engineering',
        'Aviation & Aerospace', 'Automotive', 'Chemicals', 'Machinery', 'Mining & Metals', 'Oil & Energy', 'Shipbuilding', 'Utilities',
        'Textiles', 'Paper & Forest Products', 'Railroad Manufacture', 'Farming', 'Ranching', 'Dairy', 'Fishery',
        'Primary / Secondary Education', 'Higher Education', 'Education Management', 'Research', 'Military', 'Legislative Office',
        'Judiciary', 'International Affairs', 'Government Administration', 'Executive Office', 'Law Enforcement', 'Public Safety',
        'Public Policy', 'Marketing and Advertising', 'Newspapers', 'Publishing', 'Printing', 'Information Services', 'Libraries',
        'Environmental Services', 'Package / Freight Delivery', 'Individual & Family Services', 'Religious Institutions',
        'Civic & Social Organization', 'Consumer Services', 'Transportationg / Trucking / Railroad', 'Warehousing', 'Airlines / Aviation',
        'Maritime', 'Information Technology and Services', 'Market Research', 'Public Relations and Communications', 'Design',
        'Nonprofit Organization Management', 'Fund-Raising', 'Program Development', 'Writing and Editing', 'Staffing and Recruiting',
        'Professional Training & Coaching', 'Venture Capital & Private Equity', 'Political Organization', 'Translation and Localization',
        'Computer Games', 'Events Services', 'Arts and Crafts', 'Electrical / Electronic Manufacturing', 'Online Media', 'Nanotechnology',
        'Music', 'Logistics and Supply Chain', 'Plastics', 'Computer & Network Security', 'Wireless', 'Alternative Dispute Resolution',
        'Security and Investigations', 'Facilities Services', 'Outsourcing / Offshoring', 'Health, Wellness and Fitness',
        'Alternative Medicine', 'Media Production', 'Animation', 'Commercial Real Estate', 'Capital Markets', 'Think Tanks',
        'Philanthropy', 'E-Learning', 'Wholesale', 'Import and Export', 'Mechanical or Industrial Engineering', 'Photography',
        'Human Resources', 'Business Supplies and Equipment', 'Mental Health Care', 'Graphic Design',
        'International Trade and Development', 'Wine and Spirits', 'Luxury Goods & Jewelry', 'Renewables & Environment',
        'Glass, Ceramics & Concrete', 'Packaging and Containers', 'Industrial Automation', 'Government Relations',
    ];

    static final NAME_LAST_NAME:Array<String> = [
        'Abbott', 'Abernathy', 'Abshire', 'Adams', 'Altenwerth', 'Anderson', 'Ankunding', 'Armstrong', 'Auer', 'Aufderhar', 'Bahringer',
        'Bailey', 'Balistreri', 'Barrows', 'Bartell', 'Bartoletti', 'Barton', 'Bashirian', 'Batz', 'Bauch', 'Baumbach', 'Bayer', 'Beahan',
        'Beatty', 'Bechtelar', 'Becker', 'Bednar', 'Beer', 'Beier', 'Berge', 'Bergnaum', 'Bergstrom', 'Bernhard', 'Bernier', 'Bins',
        'Blanda', 'Blick', 'Block', 'Bode', 'Boehm', 'Bogan', 'Bogisich', 'Borer', 'Bosco', 'Botsford', 'Boyer', 'Boyle', 'Bradtke',
        'Brakus', 'Braun', 'Breitenberg', 'Brekke', 'Brown', 'Bruen', 'Buckridge', 'Carroll', 'Carter', 'Cartwright', 'Casper', 'Cassin',
        'Champlin', 'Christiansen', 'Cole', 'Collier', 'Collins', 'Conn', 'Connelly', 'Conroy', 'Considine', 'Corkery', 'Cormier',
        'Corwin', 'Cremin', 'Crist', 'Crona', 'Cronin', 'Crooks', 'Cruickshank', 'Cummerata', 'Cummings', 'Dach', 'D\'Amore', 'Daniel',
        'Dare', 'Daugherty', 'Davis', 'Deckow', 'Denesik', 'Dibbert', 'Dickens', 'Dicki', 'Dickinson', 'Dietrich', 'Donnelly', 'Dooley',
        'Douglas', 'Doyle', 'DuBuque', 'Durgan', 'Ebert', 'Effertz', 'Eichmann', 'Emard', 'Emmerich', 'Erdman', 'Ernser', 'Fadel', 'Fahey',
        'Farrell', 'Fay', 'Feeney', 'Feest', 'Feil', 'Ferry', 'Fisher', 'Flatley', 'Frami', 'Franecki', 'Friesen', 'Fritsch', 'Funk',
        'Gaylord', 'Gerhold', 'Gerlach', 'Gibson', 'Gislason', 'Gleason', 'Gleichner', 'Glover', 'Goldner', 'Goodwin', 'Gorczany',
        'Gottlieb', 'Goyette', 'Grady', 'Graham', 'Grant', 'Green', 'Greenfelder', 'Greenholt', 'Grimes', 'Gulgowski', 'Gusikowski',
        'Gutkowski', 'Gutmann', 'Haag', 'Hackett', 'Hagenes', 'Hahn', 'Haley', 'Halvorson', 'Hamill', 'Hammes', 'Hand', 'Hane', 'Hansen',
        'Harber', 'Harris', 'Hartmann', 'Harvey', 'Hauck', 'Hayes', 'Heaney', 'Heathcote', 'Hegmann', 'Heidenreich', 'Heller', 'Herman',
        'Hermann', 'Hermiston', 'Herzog', 'Hessel', 'Hettinger', 'Hickle', 'Hilll', 'Hills', 'Hilpert', 'Hintz', 'Hirthe', 'Hodkiewicz',
        'Hoeger', 'Homenick', 'Hoppe', 'Howe', 'Howell', 'Hudson', 'Huel', 'Huels', 'Hyatt', 'Jacobi', 'Jacobs', 'Jacobson', 'Jakubowski',
        'Jaskolski', 'Jast', 'Jenkins', 'Jerde', 'Johns', 'Johnson', 'Johnston', 'Jones', 'Kassulke', 'Kautzer', 'Keebler', 'Keeling',
        'Kemmer', 'Kerluke', 'Kertzmann', 'Kessler', 'Kiehn', 'Kihn', 'Kilback', 'King', 'Kirlin', 'Klein', 'Kling', 'Klocko', 'Koch',
        'Koelpin', 'Koepp', 'Kohler', 'Konopelski', 'Koss', 'Kovacek', 'Kozey', 'Krajcik', 'Kreiger', 'Kris', 'Kshlerin', 'Kub', 'Kuhic',
        'Kuhlman', 'Kuhn', 'Kulas', 'Kunde', 'Kunze', 'Kuphal', 'Kutch', 'Kuvalis', 'Labadie', 'Lakin', 'Lang', 'Langosh', 'Langworth',
        'Larkin', 'Larson', 'Leannon', 'Lebsack', 'Ledner', 'Leffler', 'Legros', 'Lehner', 'Lemke', 'Lesch', 'Leuschke', 'Lind',
        'Lindgren', 'Littel', 'Little', 'Lockman', 'Lowe', 'Lubowitz', 'Lueilwitz', 'Luettgen', 'Lynch', 'Macejkovic', 'MacGyver',
        'Maggio', 'Mann', 'Mante', 'Marks', 'Marquardt', 'Marvin', 'Mayer', 'Mayert', 'McClure', 'McCullough', 'McDermott', 'McGlynn',
        'McKenzie', 'McLaughlin', 'Medhurst', 'Mertz', 'Metz', 'Miller', 'Mills', 'Mitchell', 'Moen', 'Mohr', 'Monahan', 'Moore', 'Morar',
        'Morissette', 'Mosciski', 'Mraz', 'Mueller', 'Muller', 'Murazik', 'Murphy', 'Murray', 'Nader', 'Nicolas', 'Nienow', 'Nikolaus',
        'Nitzsche', 'Nolan', 'Oberbrunner', 'O\'Connell', 'O\'Conner', 'O\'Hara', 'O\'Keefe', 'O\'Kon', 'Okuneva', 'Olson', 'Ondricka',
        'O\'Reilly', 'Orn', 'Ortiz', 'Osinski', 'Pacocha', 'Padberg', 'Pagac', 'Parisian', 'Parker', 'Paucek', 'Pfannerstill', 'Pfeffer',
        'Pollich', 'Pouros', 'Powlowski', 'Predovic', 'Price', 'Prohaska', 'Prosacco', 'Purdy', 'Quigley', 'Quitzon', 'Rath', 'Ratke',
        'Rau', 'Raynor', 'Reichel', 'Reichert', 'Reilly', 'Reinger', 'Rempel', 'Renner', 'Reynolds', 'Rice', 'Rippin', 'Ritchie', 'Robel',
        'Roberts', 'Rodriguez', 'Rogahn', 'Rohan', 'Rolfson', 'Romaguera', 'Roob', 'Rosenbaum', 'Rowe', 'Ruecker', 'Runolfsdottir',
        'Runolfsson', 'Runte', 'Russel', 'Rutherford', 'Ryan', 'Sanford', 'Satterfield', 'Sauer', 'Sawayn', 'Schaden', 'Schaefer',
        'Schamberger', 'Schiller', 'Schimmel', 'Schinner', 'Schmeler', 'Schmidt', 'Schmitt', 'Schneider', 'Schoen', 'Schowalter',
        'Schroeder', 'Schulist', 'Schultz', 'Schumm', 'Schuppe', 'Schuster', 'Senger', 'Shanahan', 'Shields', 'Simonis', 'Sipes', 'Skiles',
        'Smith', 'Smitham', 'Spencer', 'Spinka', 'Sporer', 'Stamm', 'Stanton', 'Stark', 'Stehr', 'Steuber', 'Stiedemann', 'Stokes',
        'Stoltenberg', 'Stracke', 'Streich', 'Stroman', 'Strosin', 'Swaniawski', 'Swift', 'Terry', 'Thiel', 'Thompson', 'Tillman', 'Torp',
        'Torphy', 'Towne', 'Toy', 'Trantow', 'Tremblay', 'Treutel', 'Tromp', 'Turcotte', 'Turner', 'Ullrich', 'Upton', 'Vandervort',
        'Veum', 'Volkman', 'Von', 'VonRueden', 'Waelchi', 'Walker', 'Walsh', 'Walter', 'Ward', 'Waters', 'Watsica', 'Weber', 'Wehner',
        'Weimann', 'Weissnat', 'Welch', 'West', 'White', 'Wiegand', 'Wilderman', 'Wilkinson', 'Will', 'Williamson', 'Willms', 'Windler',
        'Wintheiser', 'Wisoky', 'Wisozk', 'Witting', 'Wiza', 'Wolf', 'Wolff', 'Wuckert', 'Wunsch', 'Wyman', 'Yost', 'Yundt', 'Zboncak',
        'Zemlak', 'Ziemann', 'Zieme', 'Zulauf',
    ];

}
