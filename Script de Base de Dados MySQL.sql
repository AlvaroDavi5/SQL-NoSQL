DROP DATABASE IF EXISTS my_database;

CREATE DATABASE my_database;

USE my_database;


CREATE TABLE `table_names` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,

  PRIMARY KEY (`id`)
) DEFAULT CHARSET=utf8;

INSERT INTO `table_names`(`id`, `name`) VALUES (1, "Ana");
INSERT INTO `table_names`(`id`, `name`) VALUES (3, "João");
INSERT INTO `table_names`(`id`, `name`) VALUES (2, "Enzo");

SELECT * FROM `table_names`;
UPDATE `table_names` SET `name` = "Alfredo" WHERE `name` LIKE "Enzo";

SELECT * FROM `table_names` ORDER BY `name`;

