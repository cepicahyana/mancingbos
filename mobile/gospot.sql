/*
SQLyog Community v13.3.1 (64 bit)
MySQL - 8.4.3 : Database - indofish
*********************************************************************
*/

/*!40101 SET NAMES utf8 */;

/*!40101 SET SQL_MODE=''*/;

/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
/*Table structure for table `bookings` */

DROP TABLE IF EXISTS `bookings`;

CREATE TABLE `bookings` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint unsigned DEFAULT NULL,
  `user_id` bigint unsigned NOT NULL,
  `stall_name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `stall_id` bigint unsigned DEFAULT NULL,
  `rental_date` date DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_bookings_event` (`event_id`),
  KEY `fk_bookings_user` (`user_id`),
  CONSTRAINT `fk_bookings_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_bookings_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `bookings` */

insert  into `bookings`(`id`,`event_id`,`user_id`,`stall_name`,`status`,`created_at`,`updated_at`,`stall_id`,`rental_date`) values 
(1,2,3,'Lapak A1','approved','2026-09-19 09:25:59','2026-09-19 09:25:59',NULL,NULL),
(2,1,3,'2','cancelled','2026-09-19 13:22:38','2026-09-19 14:35:37',NULL,NULL);

/*Table structure for table `comment_likes` */

DROP TABLE IF EXISTS `comment_likes`;

CREATE TABLE `comment_likes` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `comment_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_comment_likes_user` (`comment_id`,`user_id`),
  KEY `fk_comment_likes_user` (`user_id`),
  CONSTRAINT `fk_comment_likes_comment` FOREIGN KEY (`comment_id`) REFERENCES `comments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_comment_likes_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `comment_likes` */

/*Table structure for table `comments` */

DROP TABLE IF EXISTS `comments`;

CREATE TABLE `comments` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `post_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `body` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL,
  `parent_id` bigint unsigned DEFAULT NULL,
  `reply_to_name` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_comments_post` (`post_id`),
  KEY `fk_comments_user` (`user_id`),
  CONSTRAINT `fk_comments_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_comments_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `comments` */

insert  into `comments`(`id`,`post_id`,`user_id`,`body`,`created_at`,`parent_id`,`reply_to_name`) values 
(2,2,3,'adilmb','2026-09-19 11:05:55',NULL,NULL),
(3,2,3,'@User Biasa asilk','2026-09-19 11:15:24',2,'User Biasa'),
(4,2,3,'asikk','2026-09-19 11:24:00',NULL,NULL),
(5,2,3,'????','2026-09-19 11:33:37',NULL,NULL),
(6,2,3,'????','2026-09-19 11:38:58',NULL,NULL);

/*Table structure for table `event_awards` */

DROP TABLE IF EXISTS `event_awards`;

CREATE TABLE `event_awards` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `place` tinyint NOT NULL,
  `points` int NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_event_award_place` (`event_id`,`place`),
  UNIQUE KEY `uq_event_award_user` (`event_id`,`user_id`),
  KEY `fk_event_awards_user` (`user_id`),
  CONSTRAINT `fk_event_awards_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_event_awards_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `event_awards` */

/*Table structure for table `event_registrations` */

DROP TABLE IF EXISTS `event_registrations`;

CREATE TABLE `event_registrations` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `status` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` int NOT NULL DEFAULT '0',
  `payment_provider` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'xendit',
  `external_id` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_event_reg_user` (`event_id`,`user_id`),
  KEY `fk_event_reg_user` (`user_id`),
  CONSTRAINT `fk_event_reg_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_event_reg_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `event_registrations` */

insert  into `event_registrations`(`id`,`event_id`,`user_id`,`status`,`amount`,`payment_provider`,`external_id`,`created_at`,`updated_at`) values 
(1,1,3,'paid',0,'xendit',NULL,'2026-09-19 13:05:07','2026-09-19 13:05:07'),
(2,3,3,'pending_payment',100000,'xendit',NULL,'2026-09-19 13:20:36','2026-09-19 13:20:36');

/*Table structure for table `events` */

DROP TABLE IF EXISTS `events`;

CREATE TABLE `events` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `owner_id` bigint unsigned NOT NULL,
  `title` varchar(180) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `date` date NOT NULL,
  `location` varchar(180) COLLATE utf8mb4_unicode_ci NOT NULL,
  `rental_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `stall_id` bigint unsigned DEFAULT NULL,
  `max_participants` int NOT NULL DEFAULT '0',
  `category` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'santuy',
  `registration_fee` int NOT NULL DEFAULT '0',
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_events_owner` (`owner_id`),
  CONSTRAINT `fk_events_owner` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `events` */

insert  into `events`(`id`,`owner_id`,`title`,`description`,`date`,`location`,`rental_enabled`,`created_at`,`updated_at`,`stall_id`,`max_participants`,`category`,`registration_fee`,`latitude`,`longitude`) values 
(1,4,'Lomba Mancing Danau Cirata','Lomba mancing terbuka. Pemilik lapak mengizinkan penyewaan spot di tepi danau.','2026-10-12','Danau Cirata, Purwakarta',1,'2026-09-19 09:25:59','2026-09-19 09:25:59',NULL,0,'galapung',0,-6.7167,107.35),
(2,4,'Mancing Santai Waduk Jatiluhur','Event santai untuk pencinta mancing. Sewa lapak dibuka terbatas.','2026-11-02','Waduk Jatiluhur, Purwakarta',1,'2026-09-19 09:25:59','2026-09-19 09:25:59',NULL,0,'galapung',0,-6.5236,107.3667),
(3,6,'Lomba Berat Cirata Open 2026','Juara berdasarkan total berat tangkapan. Hadiah trophy + poin IndoFish.','2026-10-18','Danau Cirata, Purwakarta, Jawa Barat',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',1,80,'kilogebrus',100000,-6.7167,107.35),
(4,6,'Mancing Santuy Cirata Weekend','Santai keluarga, sewa lapak dibuka.','2026-10-25','Danau Cirata, Purwakarta, Jawa Barat',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',2,40,'galapung',35000,-6.7167,107.35),
(5,7,'Jatiluhur Team Challenge','Lomba beregu 3 orang per tim.','2026-11-08','Waduk Jatiluhur, Purwakarta, Jawa Barat',0,'2026-09-19 13:17:45','2026-09-19 13:17:45',3,60,'beregu',150000,-6.5236,107.3667),
(6,7,'Jatiluhur Night Fishing','Mancing malam, lampu disediakan.','2026-11-15','Waduk Jatiluhur, Purwakarta, Jawa Barat',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',4,35,'galapung',40000,-6.5236,107.3667),
(7,8,'Gajah Mungkur Lomba Jumlah','Siapa paling banyak ikan dalam 6 jam.','2026-10-20','Waduk Gajah Mungkur, Wonogiri, Jawa Tengah',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',5,50,'galatama',75000,-7.7833,110.9167),
(8,9,'Saguling Open Weight','Lomba berat kategori umum & junior.','2026-11-01','Waduk Saguling, Bandung Barat, Jawa Barat',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',6,70,'kilogebrus',85000,-6.9167,107.35),
(9,10,'Cileunca Cool Morning','Event santai pagi di dataran tinggi.','2026-10-12','Situ Cileunca, Bandung, Jawa Barat',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',7,25,'galapung',30000,-7.1833,107.55),
(10,11,'Muara Angke Coastal Cup','Lomba laut & muara — kategori berat.','2026-11-22','Muara Angke, Jakarta Utara',0,'2026-09-19 13:17:45','2026-09-19 13:17:45',8,45,'kilogebrus',125000,-6.1089,106.7789),
(11,12,'Rawa Pening Classic Meet','Kumpul komunitas, sewa spot harian.','2026-10-28','Rawa Pening, Semarang, Jawa Tengah',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',9,40,'galapung',25000,-7.2833,110.4333),
(12,13,'Kedung Ombo Team Battle','Battle antar komunitas Jawa Tengah.','2026-12-06','Waduk Kedung Ombo, Sragen, Jawa Tengah',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,90,'beregu',200000,-7.25,110.8333),
(13,8,'Wonogiri Weekend Santuy','Mancing santai akhir pekan.','2026-11-29','Waduk Gajah Mungkur, Wonogiri, Jawa Tengah',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',5,30,'galapung',20000,-7.7833,110.9167),
(14,11,'Jakarta Angler Meetup','Meetup pemancing Jakarta & sekitar.','2026-12-13','Muara Angke, Jakarta Utara',1,'2026-09-19 13:17:45','2026-09-19 13:17:45',8,50,'galapung',50000,-6.1089,106.7789);

/*Table structure for table `follows` */

DROP TABLE IF EXISTS `follows`;

CREATE TABLE `follows` (
  `follower_id` bigint unsigned NOT NULL,
  `following_id` bigint unsigned NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`follower_id`,`following_id`),
  KEY `fk_follows_following` (`following_id`),
  CONSTRAINT `fk_follows_follower` FOREIGN KEY (`follower_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_follows_following` FOREIGN KEY (`following_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `follows` */

/*Table structure for table `likes` */

DROP TABLE IF EXISTS `likes`;

CREATE TABLE `likes` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `post_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_likes_post_user` (`post_id`,`user_id`),
  KEY `fk_likes_user` (`user_id`),
  CONSTRAINT `fk_likes_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_likes_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `likes` */

insert  into `likes`(`id`,`post_id`,`user_id`,`created_at`) values 
(2,2,3,'2026-09-19 11:05:33'),
(3,6,3,'2026-09-19 12:21:32'),
(4,4,3,'2026-09-19 12:21:36');

/*Table structure for table `post_images` */

DROP TABLE IF EXISTS `post_images`;

CREATE TABLE `post_images` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `post_id` bigint unsigned NOT NULL,
  `image_path` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `sort_order` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  KEY `fk_post_images_post` (`post_id`),
  CONSTRAINT `fk_post_images_post` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `post_images` */

insert  into `post_images`(`id`,`post_id`,`image_path`,`sort_order`) values 
(5,6,'1789793155707605800_3_0.jpg',0),
(6,6,'1789793155710706000_3_1.jpg',1),
(7,6,'1789793155711735400_3_2.jpg',2),
(10,8,'1789795207336108800_3_0.jpg',0);

/*Table structure for table `posts` */

DROP TABLE IF EXISTS `posts`;

CREATE TABLE `posts` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `caption` text COLLATE utf8mb4_unicode_ci,
  `image_path` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `location` varchar(180) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` double DEFAULT NULL,
  `longitude` double DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_posts_user` (`user_id`),
  CONSTRAINT `fk_posts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `posts` */

insert  into `posts`(`id`,`user_id`,`caption`,`image_path`,`created_at`,`updated_at`,`location`,`latitude`,`longitude`) values 
(2,3,'hassss','1789790729088284900_3.jpg','2026-09-19 11:05:29','2026-09-19 11:05:29',NULL,NULL,NULL),
(3,3,'familyy','1789790964454657800_3.jpg','2026-09-19 11:09:24','2026-09-19 11:09:24',NULL,NULL,NULL),
(4,3,'oke sipp','1789791250929587100_3.jpg','2026-09-19 11:14:10','2026-09-19 11:14:10',NULL,NULL,NULL),
(6,3,'','1789793155707605800_3_0.jpg','2026-09-19 11:45:55','2026-09-19 11:45:55','danau cirara',NULL,NULL),
(8,3,'','1789795207336108800_3_0.jpg','2026-09-19 12:20:07','2026-09-19 12:20:07','FJFR+93 Tanggulun Barat, Kabupaten Subang, Jawa Barat, Indonesia',-6.526576728812018,107.64016952365637);

/*Table structure for table `stall_open_dates` */

DROP TABLE IF EXISTS `stall_open_dates`;

CREATE TABLE `stall_open_dates` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `stall_id` bigint unsigned NOT NULL,
  `open_date` date NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_stall_open` (`stall_id`,`open_date`),
  CONSTRAINT `fk_stall_open_stall` FOREIGN KEY (`stall_id`) REFERENCES `stalls` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=1485 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `stall_open_dates` */

insert  into `stall_open_dates`(`id`,`stall_id`,`open_date`,`created_at`) values 
(1,11,'2026-09-19','2026-09-19 14:39:37'),
(2,11,'2026-09-20','2026-09-19 14:39:37'),
(3,11,'2026-09-21','2026-09-19 14:39:37'),
(4,11,'2026-09-22','2026-09-19 14:39:37'),
(5,11,'2026-09-23','2026-09-19 14:39:37'),
(6,11,'2026-09-24','2026-09-19 14:39:37'),
(7,11,'2026-09-25','2026-09-19 14:39:37'),
(8,11,'2026-09-26','2026-09-19 14:39:37'),
(9,11,'2026-09-27','2026-09-19 14:39:37'),
(10,11,'2026-09-28','2026-09-19 14:39:37'),
(11,11,'2026-09-29','2026-09-19 14:39:37'),
(12,11,'2026-09-30','2026-09-19 14:39:37'),
(13,11,'2026-10-01','2026-09-19 14:39:37'),
(14,11,'2026-10-02','2026-09-19 14:39:37'),
(15,11,'2026-10-03','2026-09-19 14:39:37'),
(16,11,'2026-10-04','2026-09-19 14:39:37'),
(17,11,'2026-10-05','2026-09-19 14:39:37'),
(18,11,'2026-10-06','2026-09-19 14:39:37'),
(19,11,'2026-10-07','2026-09-19 14:39:37'),
(20,11,'2026-10-08','2026-09-19 14:39:37'),
(21,11,'2026-10-09','2026-09-19 14:39:37'),
(22,12,'2026-09-19','2026-09-19 14:39:37'),
(23,12,'2026-09-20','2026-09-19 14:39:37'),
(24,12,'2026-09-21','2026-09-19 14:39:37'),
(25,12,'2026-09-22','2026-09-19 14:39:37'),
(26,12,'2026-09-23','2026-09-19 14:39:37'),
(27,12,'2026-09-24','2026-09-19 14:39:37'),
(28,12,'2026-09-25','2026-09-19 14:39:37'),
(29,12,'2026-09-26','2026-09-19 14:39:37'),
(30,12,'2026-09-27','2026-09-19 14:39:37'),
(31,12,'2026-09-28','2026-09-19 14:39:37'),
(32,12,'2026-09-29','2026-09-19 14:39:37'),
(33,12,'2026-09-30','2026-09-19 14:39:37'),
(34,12,'2026-10-01','2026-09-19 14:39:37'),
(35,12,'2026-10-02','2026-09-19 14:39:37'),
(36,13,'2026-09-19','2026-09-19 14:39:37'),
(37,13,'2026-09-20','2026-09-19 14:39:37'),
(38,13,'2026-09-21','2026-09-19 14:39:37'),
(39,13,'2026-09-22','2026-09-19 14:39:37'),
(40,13,'2026-09-23','2026-09-19 14:39:37'),
(41,13,'2026-09-24','2026-09-19 14:39:37'),
(42,13,'2026-09-25','2026-09-19 14:39:37'),
(43,13,'2026-09-26','2026-09-19 14:39:37'),
(44,13,'2026-09-27','2026-09-19 14:39:37'),
(45,13,'2026-09-28','2026-09-19 14:39:37'),
(46,13,'2026-09-29','2026-09-19 14:39:37'),
(47,13,'2026-09-30','2026-09-19 14:39:37'),
(48,13,'2026-10-01','2026-09-19 14:39:37'),
(49,13,'2026-10-02','2026-09-19 14:39:37'),
(50,13,'2026-10-03','2026-09-19 14:39:37'),
(51,13,'2026-10-04','2026-09-19 14:39:37'),
(52,13,'2026-10-05','2026-09-19 14:39:37'),
(53,13,'2026-10-06','2026-09-19 14:39:37'),
(54,14,'2026-09-19','2026-09-19 14:39:37'),
(55,14,'2026-09-20','2026-09-19 14:39:37'),
(56,14,'2026-09-26','2026-09-19 14:39:37'),
(57,14,'2026-09-27','2026-09-19 14:39:37'),
(58,14,'2026-10-03','2026-09-19 14:39:37'),
(59,14,'2026-10-04','2026-09-19 14:39:37'),
(60,14,'2026-10-10','2026-09-19 14:39:37'),
(61,14,'2026-10-11','2026-09-19 14:39:37'),
(62,14,'2026-10-17','2026-09-19 14:39:37'),
(63,14,'2026-10-18','2026-09-19 14:39:37'),
(64,15,'2026-09-19','2026-09-19 14:39:37'),
(65,15,'2026-09-20','2026-09-19 14:39:37'),
(66,15,'2026-09-21','2026-09-19 14:39:37'),
(67,15,'2026-09-22','2026-09-19 14:39:37'),
(68,15,'2026-09-23','2026-09-19 14:39:37'),
(69,15,'2026-09-24','2026-09-19 14:39:37'),
(70,15,'2026-09-25','2026-09-19 14:39:37'),
(71,15,'2026-09-26','2026-09-19 14:39:37'),
(72,15,'2026-09-27','2026-09-19 14:39:37'),
(73,15,'2026-09-28','2026-09-19 14:39:37'),
(74,15,'2026-09-29','2026-09-19 14:39:37'),
(75,15,'2026-09-30','2026-09-19 14:39:37'),
(76,15,'2026-10-01','2026-09-19 14:39:37'),
(77,15,'2026-10-02','2026-09-19 14:39:37'),
(78,15,'2026-10-03','2026-09-19 14:39:37'),
(79,15,'2026-10-04','2026-09-19 14:39:37'),
(80,15,'2026-10-05','2026-09-19 14:39:37'),
(81,15,'2026-10-06','2026-09-19 14:39:37'),
(82,15,'2026-10-07','2026-09-19 14:39:37'),
(83,15,'2026-10-08','2026-09-19 14:39:37'),
(84,16,'2026-09-19','2026-09-19 14:39:37'),
(85,16,'2026-09-20','2026-09-19 14:39:37'),
(86,16,'2026-09-21','2026-09-19 14:39:37'),
(87,16,'2026-09-22','2026-09-19 14:39:37'),
(88,16,'2026-09-23','2026-09-19 14:39:37'),
(89,16,'2026-09-24','2026-09-19 14:39:37'),
(90,16,'2026-09-25','2026-09-19 14:39:37'),
(91,16,'2026-09-26','2026-09-19 14:39:37'),
(92,16,'2026-09-27','2026-09-19 14:39:37'),
(93,16,'2026-09-28','2026-09-19 14:39:37'),
(94,16,'2026-09-29','2026-09-19 14:39:37'),
(95,16,'2026-09-30','2026-09-19 14:39:37'),
(96,16,'2026-10-01','2026-09-19 14:39:37'),
(97,16,'2026-10-02','2026-09-19 14:39:37'),
(98,16,'2026-10-03','2026-09-19 14:39:37'),
(99,16,'2026-10-04','2026-09-19 14:39:37'),
(100,17,'2026-09-19','2026-09-19 14:39:37'),
(101,17,'2026-09-20','2026-09-19 14:39:37'),
(102,17,'2026-09-21','2026-09-19 14:39:37'),
(103,17,'2026-09-22','2026-09-19 14:39:37'),
(104,17,'2026-09-23','2026-09-19 14:39:37'),
(105,17,'2026-09-24','2026-09-19 14:39:37'),
(106,17,'2026-09-25','2026-09-19 14:39:37'),
(107,17,'2026-09-26','2026-09-19 14:39:37'),
(108,17,'2026-09-27','2026-09-19 14:39:37'),
(109,17,'2026-09-28','2026-09-19 14:39:37'),
(110,17,'2026-09-29','2026-09-19 14:39:37'),
(111,17,'2026-09-30','2026-09-19 14:39:37'),
(112,17,'2026-10-01','2026-09-19 14:39:37'),
(113,17,'2026-10-02','2026-09-19 14:39:37'),
(114,17,'2026-10-03','2026-09-19 14:39:37'),
(115,17,'2026-10-04','2026-09-19 14:39:37'),
(116,17,'2026-10-05','2026-09-19 14:39:37'),
(117,17,'2026-10-06','2026-09-19 14:39:37'),
(118,17,'2026-10-07','2026-09-19 14:39:37'),
(119,17,'2026-10-08','2026-09-19 14:39:37'),
(120,17,'2026-10-09','2026-09-19 14:39:37'),
(121,18,'2026-09-19','2026-09-19 14:39:37'),
(122,18,'2026-09-20','2026-09-19 14:39:37'),
(123,18,'2026-09-21','2026-09-19 14:39:37'),
(124,18,'2026-09-22','2026-09-19 14:39:37'),
(125,18,'2026-09-23','2026-09-19 14:39:37'),
(126,18,'2026-09-24','2026-09-19 14:39:37'),
(127,18,'2026-09-25','2026-09-19 14:39:37'),
(128,18,'2026-09-26','2026-09-19 14:39:37'),
(129,18,'2026-09-27','2026-09-19 14:39:37'),
(130,18,'2026-09-28','2026-09-19 14:39:37'),
(131,18,'2026-09-29','2026-09-19 14:39:37'),
(132,18,'2026-09-30','2026-09-19 14:39:37'),
(133,18,'2026-10-01','2026-09-19 14:39:37'),
(134,18,'2026-10-02','2026-09-19 14:39:37'),
(135,19,'2026-09-19','2026-09-19 14:39:37'),
(136,19,'2026-09-20','2026-09-19 14:39:37'),
(137,19,'2026-09-21','2026-09-19 14:39:37'),
(138,19,'2026-09-22','2026-09-19 14:39:37'),
(139,19,'2026-09-23','2026-09-19 14:39:37'),
(140,19,'2026-09-24','2026-09-19 14:39:37'),
(141,19,'2026-09-25','2026-09-19 14:39:37'),
(142,19,'2026-09-26','2026-09-19 14:39:37'),
(143,19,'2026-09-27','2026-09-19 14:39:37'),
(144,19,'2026-09-28','2026-09-19 14:39:37'),
(145,19,'2026-09-29','2026-09-19 14:39:37'),
(146,19,'2026-09-30','2026-09-19 14:39:37'),
(147,19,'2026-10-01','2026-09-19 14:39:37'),
(148,19,'2026-10-02','2026-09-19 14:39:37'),
(149,19,'2026-10-03','2026-09-19 14:39:37'),
(150,19,'2026-10-04','2026-09-19 14:39:37'),
(151,19,'2026-10-05','2026-09-19 14:39:37'),
(152,19,'2026-10-06','2026-09-19 14:39:37'),
(153,20,'2026-09-19','2026-09-19 14:39:37'),
(154,20,'2026-09-20','2026-09-19 14:39:37'),
(155,20,'2026-09-21','2026-09-19 14:39:37'),
(156,20,'2026-09-22','2026-09-19 14:39:37'),
(157,20,'2026-09-23','2026-09-19 14:39:37'),
(158,20,'2026-09-24','2026-09-19 14:39:37'),
(159,20,'2026-09-25','2026-09-19 14:39:37'),
(160,20,'2026-09-26','2026-09-19 14:39:37'),
(161,20,'2026-09-27','2026-09-19 14:39:37'),
(162,20,'2026-09-28','2026-09-19 14:39:37'),
(163,20,'2026-09-29','2026-09-19 14:39:37'),
(164,20,'2026-09-30','2026-09-19 14:39:37'),
(165,20,'2026-10-01','2026-09-19 14:39:37'),
(166,20,'2026-10-02','2026-09-19 14:39:37'),
(167,20,'2026-10-03','2026-09-19 14:39:37'),
(168,20,'2026-10-04','2026-09-19 14:39:37'),
(169,20,'2026-10-05','2026-09-19 14:39:37'),
(170,20,'2026-10-06','2026-09-19 14:39:37'),
(171,20,'2026-10-07','2026-09-19 14:39:37'),
(172,20,'2026-10-08','2026-09-19 14:39:37'),
(173,20,'2026-10-09','2026-09-19 14:39:37'),
(174,21,'2026-09-19','2026-09-19 14:39:37'),
(175,21,'2026-09-20','2026-09-19 14:39:37'),
(176,21,'2026-09-21','2026-09-19 14:39:37'),
(177,21,'2026-09-22','2026-09-19 14:39:37'),
(178,21,'2026-09-23','2026-09-19 14:39:37'),
(179,21,'2026-09-24','2026-09-19 14:39:37'),
(180,21,'2026-09-25','2026-09-19 14:39:37'),
(181,21,'2026-09-26','2026-09-19 14:39:37'),
(182,21,'2026-09-27','2026-09-19 14:39:37'),
(183,21,'2026-09-28','2026-09-19 14:39:37'),
(184,21,'2026-09-29','2026-09-19 14:39:37'),
(185,21,'2026-09-30','2026-09-19 14:39:37'),
(221,12,'2026-10-03','2026-09-19 14:52:46'),
(222,12,'2026-10-04','2026-09-19 14:52:46'),
(223,12,'2026-10-05','2026-09-19 14:52:46'),
(224,12,'2026-10-06','2026-09-19 14:52:46'),
(225,12,'2026-10-07','2026-09-19 14:52:46'),
(226,12,'2026-10-08','2026-09-19 14:52:46'),
(227,12,'2026-10-09','2026-09-19 14:52:46'),
(246,13,'2026-10-07','2026-09-19 14:52:46'),
(247,13,'2026-10-08','2026-09-19 14:52:46'),
(248,13,'2026-10-09','2026-09-19 14:52:46'),
(275,15,'2026-10-09','2026-09-19 14:52:46'),
(292,16,'2026-10-05','2026-09-19 14:52:46'),
(293,16,'2026-10-06','2026-09-19 14:52:46'),
(294,16,'2026-10-07','2026-09-19 14:52:46'),
(295,16,'2026-10-08','2026-09-19 14:52:46'),
(296,16,'2026-10-09','2026-09-19 14:52:46'),
(332,18,'2026-10-03','2026-09-19 14:52:46'),
(333,18,'2026-10-04','2026-09-19 14:52:46'),
(334,18,'2026-10-05','2026-09-19 14:52:46'),
(335,18,'2026-10-06','2026-09-19 14:52:46'),
(336,18,'2026-10-07','2026-09-19 14:52:46'),
(337,18,'2026-10-08','2026-09-19 14:52:46'),
(338,18,'2026-10-09','2026-09-19 14:52:46'),
(357,19,'2026-10-07','2026-09-19 14:52:46'),
(358,19,'2026-10-08','2026-09-19 14:52:46'),
(359,19,'2026-10-09','2026-09-19 14:52:46'),
(393,21,'2026-10-01','2026-09-19 14:52:46'),
(394,21,'2026-10-02','2026-09-19 14:52:46'),
(395,21,'2026-10-03','2026-09-19 14:52:46'),
(396,21,'2026-10-04','2026-09-19 14:52:46'),
(397,21,'2026-10-05','2026-09-19 14:52:46'),
(398,21,'2026-10-06','2026-09-19 14:52:46'),
(399,21,'2026-10-07','2026-09-19 14:52:46'),
(400,21,'2026-10-08','2026-09-19 14:52:46'),
(401,21,'2026-10-09','2026-09-19 14:52:46'),
(618,1,'2026-09-19','2026-09-19 14:56:18'),
(619,1,'2026-09-20','2026-09-19 14:56:18'),
(620,1,'2026-09-21','2026-09-19 14:56:18'),
(621,1,'2026-09-22','2026-09-19 14:56:18'),
(622,1,'2026-09-23','2026-09-19 14:56:18'),
(623,1,'2026-09-24','2026-09-19 14:56:18'),
(624,1,'2026-09-25','2026-09-19 14:56:18'),
(625,1,'2026-09-26','2026-09-19 14:56:18'),
(626,1,'2026-09-27','2026-09-19 14:56:18'),
(627,1,'2026-09-28','2026-09-19 14:56:18'),
(628,1,'2026-09-29','2026-09-19 14:56:18'),
(629,1,'2026-09-30','2026-09-19 14:56:18'),
(630,1,'2026-10-01','2026-09-19 14:56:18'),
(631,1,'2026-10-02','2026-09-19 14:56:18'),
(632,1,'2026-10-03','2026-09-19 14:56:18'),
(633,1,'2026-10-04','2026-09-19 14:56:18'),
(634,1,'2026-10-05','2026-09-19 14:56:18'),
(635,1,'2026-10-06','2026-09-19 14:56:18'),
(636,1,'2026-10-07','2026-09-19 14:56:18'),
(637,1,'2026-10-08','2026-09-19 14:56:18'),
(638,1,'2026-10-09','2026-09-19 14:56:18'),
(639,2,'2026-09-19','2026-09-19 14:56:18'),
(640,2,'2026-09-20','2026-09-19 14:56:18'),
(641,2,'2026-09-21','2026-09-19 14:56:18'),
(642,2,'2026-09-22','2026-09-19 14:56:18'),
(643,2,'2026-09-23','2026-09-19 14:56:18'),
(644,2,'2026-09-24','2026-09-19 14:56:18'),
(645,2,'2026-09-25','2026-09-19 14:56:18'),
(646,2,'2026-09-26','2026-09-19 14:56:18'),
(647,2,'2026-09-27','2026-09-19 14:56:18'),
(648,2,'2026-09-28','2026-09-19 14:56:18'),
(649,2,'2026-09-29','2026-09-19 14:56:18'),
(650,2,'2026-09-30','2026-09-19 14:56:18'),
(651,2,'2026-10-01','2026-09-19 14:56:18'),
(652,2,'2026-10-02','2026-09-19 14:56:18'),
(653,2,'2026-10-03','2026-09-19 14:56:18'),
(654,2,'2026-10-04','2026-09-19 14:56:18'),
(655,2,'2026-10-05','2026-09-19 14:56:18'),
(656,2,'2026-10-06','2026-09-19 14:56:18'),
(657,2,'2026-10-07','2026-09-19 14:56:18'),
(658,2,'2026-10-08','2026-09-19 14:56:18'),
(659,2,'2026-10-09','2026-09-19 14:56:18'),
(660,3,'2026-09-19','2026-09-19 14:56:18'),
(661,3,'2026-09-20','2026-09-19 14:56:18'),
(662,3,'2026-09-21','2026-09-19 14:56:18'),
(663,3,'2026-09-22','2026-09-19 14:56:18'),
(664,3,'2026-09-23','2026-09-19 14:56:18'),
(665,3,'2026-09-24','2026-09-19 14:56:18'),
(666,3,'2026-09-25','2026-09-19 14:56:18'),
(667,3,'2026-09-26','2026-09-19 14:56:18'),
(668,3,'2026-09-27','2026-09-19 14:56:18'),
(669,3,'2026-09-28','2026-09-19 14:56:18'),
(670,3,'2026-09-29','2026-09-19 14:56:18'),
(671,3,'2026-09-30','2026-09-19 14:56:18'),
(672,3,'2026-10-01','2026-09-19 14:56:18'),
(673,3,'2026-10-02','2026-09-19 14:56:18'),
(674,3,'2026-10-03','2026-09-19 14:56:18'),
(675,3,'2026-10-04','2026-09-19 14:56:18'),
(676,3,'2026-10-05','2026-09-19 14:56:18'),
(677,3,'2026-10-06','2026-09-19 14:56:18'),
(678,3,'2026-10-07','2026-09-19 14:56:18'),
(679,3,'2026-10-08','2026-09-19 14:56:18'),
(680,3,'2026-10-09','2026-09-19 14:56:18'),
(681,4,'2026-09-19','2026-09-19 14:56:18'),
(682,4,'2026-09-20','2026-09-19 14:56:18'),
(683,4,'2026-09-21','2026-09-19 14:56:18'),
(684,4,'2026-09-22','2026-09-19 14:56:18'),
(685,4,'2026-09-23','2026-09-19 14:56:18'),
(686,4,'2026-09-24','2026-09-19 14:56:18'),
(687,4,'2026-09-25','2026-09-19 14:56:18'),
(688,4,'2026-09-26','2026-09-19 14:56:18'),
(689,4,'2026-09-27','2026-09-19 14:56:18'),
(690,4,'2026-09-28','2026-09-19 14:56:18'),
(691,4,'2026-09-29','2026-09-19 14:56:18'),
(692,4,'2026-09-30','2026-09-19 14:56:18'),
(693,4,'2026-10-01','2026-09-19 14:56:18'),
(694,4,'2026-10-02','2026-09-19 14:56:18'),
(695,4,'2026-10-03','2026-09-19 14:56:18'),
(696,4,'2026-10-04','2026-09-19 14:56:18'),
(697,4,'2026-10-05','2026-09-19 14:56:18'),
(698,4,'2026-10-06','2026-09-19 14:56:18'),
(699,4,'2026-10-07','2026-09-19 14:56:18'),
(700,4,'2026-10-08','2026-09-19 14:56:18'),
(701,4,'2026-10-09','2026-09-19 14:56:18'),
(702,5,'2026-09-19','2026-09-19 14:56:18'),
(703,5,'2026-09-20','2026-09-19 14:56:18'),
(704,5,'2026-09-21','2026-09-19 14:56:18'),
(705,5,'2026-09-22','2026-09-19 14:56:18'),
(706,5,'2026-09-23','2026-09-19 14:56:18'),
(707,5,'2026-09-24','2026-09-19 14:56:18'),
(708,5,'2026-09-25','2026-09-19 14:56:18'),
(709,5,'2026-09-26','2026-09-19 14:56:18'),
(710,5,'2026-09-27','2026-09-19 14:56:18'),
(711,5,'2026-09-28','2026-09-19 14:56:18'),
(712,5,'2026-09-29','2026-09-19 14:56:18'),
(713,5,'2026-09-30','2026-09-19 14:56:18'),
(714,5,'2026-10-01','2026-09-19 14:56:18'),
(715,5,'2026-10-02','2026-09-19 14:56:18'),
(716,5,'2026-10-03','2026-09-19 14:56:18'),
(717,5,'2026-10-04','2026-09-19 14:56:18'),
(718,5,'2026-10-05','2026-09-19 14:56:18'),
(719,5,'2026-10-06','2026-09-19 14:56:18'),
(720,5,'2026-10-07','2026-09-19 14:56:18'),
(721,5,'2026-10-08','2026-09-19 14:56:18'),
(722,5,'2026-10-09','2026-09-19 14:56:18'),
(723,6,'2026-09-19','2026-09-19 14:56:18'),
(724,6,'2026-09-20','2026-09-19 14:56:18'),
(725,6,'2026-09-21','2026-09-19 14:56:18'),
(726,6,'2026-09-22','2026-09-19 14:56:18'),
(727,6,'2026-09-23','2026-09-19 14:56:18'),
(728,6,'2026-09-24','2026-09-19 14:56:18'),
(729,6,'2026-09-25','2026-09-19 14:56:18'),
(730,6,'2026-09-26','2026-09-19 14:56:18'),
(731,6,'2026-09-27','2026-09-19 14:56:18'),
(732,6,'2026-09-28','2026-09-19 14:56:18'),
(733,6,'2026-09-29','2026-09-19 14:56:18'),
(734,6,'2026-09-30','2026-09-19 14:56:18'),
(735,6,'2026-10-01','2026-09-19 14:56:18'),
(736,6,'2026-10-02','2026-09-19 14:56:18'),
(737,6,'2026-10-03','2026-09-19 14:56:18'),
(738,6,'2026-10-04','2026-09-19 14:56:18'),
(739,6,'2026-10-05','2026-09-19 14:56:18'),
(740,6,'2026-10-06','2026-09-19 14:56:18'),
(741,6,'2026-10-07','2026-09-19 14:56:18'),
(742,6,'2026-10-08','2026-09-19 14:56:18'),
(743,6,'2026-10-09','2026-09-19 14:56:18'),
(744,7,'2026-09-19','2026-09-19 14:56:18'),
(745,7,'2026-09-20','2026-09-19 14:56:18'),
(746,7,'2026-09-21','2026-09-19 14:56:18'),
(747,7,'2026-09-22','2026-09-19 14:56:18'),
(748,7,'2026-09-23','2026-09-19 14:56:18'),
(749,7,'2026-09-24','2026-09-19 14:56:18'),
(750,7,'2026-09-25','2026-09-19 14:56:18'),
(751,7,'2026-09-26','2026-09-19 14:56:18'),
(752,7,'2026-09-27','2026-09-19 14:56:18'),
(753,7,'2026-09-28','2026-09-19 14:56:18'),
(754,7,'2026-09-29','2026-09-19 14:56:18'),
(755,7,'2026-09-30','2026-09-19 14:56:18'),
(756,7,'2026-10-01','2026-09-19 14:56:18'),
(757,7,'2026-10-02','2026-09-19 14:56:18'),
(758,7,'2026-10-03','2026-09-19 14:56:18'),
(759,7,'2026-10-04','2026-09-19 14:56:18'),
(760,7,'2026-10-05','2026-09-19 14:56:18'),
(761,7,'2026-10-06','2026-09-19 14:56:18'),
(762,7,'2026-10-07','2026-09-19 14:56:18'),
(763,7,'2026-10-08','2026-09-19 14:56:18'),
(764,7,'2026-10-09','2026-09-19 14:56:18'),
(765,8,'2026-09-19','2026-09-19 14:56:18'),
(766,8,'2026-09-20','2026-09-19 14:56:18'),
(767,8,'2026-09-21','2026-09-19 14:56:18'),
(768,8,'2026-09-22','2026-09-19 14:56:18'),
(769,8,'2026-09-23','2026-09-19 14:56:18'),
(770,8,'2026-09-24','2026-09-19 14:56:18'),
(771,8,'2026-09-25','2026-09-19 14:56:18'),
(772,8,'2026-09-26','2026-09-19 14:56:18'),
(773,8,'2026-09-27','2026-09-19 14:56:18'),
(774,8,'2026-09-28','2026-09-19 14:56:18'),
(775,8,'2026-09-29','2026-09-19 14:56:18'),
(776,8,'2026-09-30','2026-09-19 14:56:18'),
(777,8,'2026-10-01','2026-09-19 14:56:18'),
(778,8,'2026-10-02','2026-09-19 14:56:18'),
(779,8,'2026-10-03','2026-09-19 14:56:18'),
(780,8,'2026-10-04','2026-09-19 14:56:18'),
(781,8,'2026-10-05','2026-09-19 14:56:18'),
(782,8,'2026-10-06','2026-09-19 14:56:18'),
(783,8,'2026-10-07','2026-09-19 14:56:18'),
(784,8,'2026-10-08','2026-09-19 14:56:18'),
(785,8,'2026-10-09','2026-09-19 14:56:18'),
(786,9,'2026-09-19','2026-09-19 14:56:18'),
(787,9,'2026-09-20','2026-09-19 14:56:18'),
(788,9,'2026-09-21','2026-09-19 14:56:18'),
(789,9,'2026-09-22','2026-09-19 14:56:18'),
(790,9,'2026-09-23','2026-09-19 14:56:18'),
(791,9,'2026-09-24','2026-09-19 14:56:18'),
(792,9,'2026-09-25','2026-09-19 14:56:18'),
(793,9,'2026-09-26','2026-09-19 14:56:18'),
(794,9,'2026-09-27','2026-09-19 14:56:18'),
(795,9,'2026-09-28','2026-09-19 14:56:18'),
(796,9,'2026-09-29','2026-09-19 14:56:18'),
(797,9,'2026-09-30','2026-09-19 14:56:18'),
(798,9,'2026-10-01','2026-09-19 14:56:18'),
(799,9,'2026-10-02','2026-09-19 14:56:18'),
(800,9,'2026-10-03','2026-09-19 14:56:18'),
(801,9,'2026-10-04','2026-09-19 14:56:18'),
(802,9,'2026-10-05','2026-09-19 14:56:18'),
(803,9,'2026-10-06','2026-09-19 14:56:18'),
(804,9,'2026-10-07','2026-09-19 14:56:18'),
(805,9,'2026-10-08','2026-09-19 14:56:18'),
(806,9,'2026-10-09','2026-09-19 14:56:18'),
(807,10,'2026-09-19','2026-09-19 14:56:18'),
(808,10,'2026-09-20','2026-09-19 14:56:18'),
(809,10,'2026-09-21','2026-09-19 14:56:18'),
(810,10,'2026-09-22','2026-09-19 14:56:18'),
(811,10,'2026-09-23','2026-09-19 14:56:18'),
(812,10,'2026-09-24','2026-09-19 14:56:18'),
(813,10,'2026-09-25','2026-09-19 14:56:18'),
(814,10,'2026-09-26','2026-09-19 14:56:18'),
(815,10,'2026-09-27','2026-09-19 14:56:18'),
(816,10,'2026-09-28','2026-09-19 14:56:18'),
(817,10,'2026-09-29','2026-09-19 14:56:18'),
(818,10,'2026-09-30','2026-09-19 14:56:18'),
(819,10,'2026-10-01','2026-09-19 14:56:18'),
(820,10,'2026-10-02','2026-09-19 14:56:18'),
(821,10,'2026-10-03','2026-09-19 14:56:18'),
(822,10,'2026-10-04','2026-09-19 14:56:18'),
(823,10,'2026-10-05','2026-09-19 14:56:18'),
(824,10,'2026-10-06','2026-09-19 14:56:18'),
(825,10,'2026-10-07','2026-09-19 14:56:18'),
(826,10,'2026-10-08','2026-09-19 14:56:18'),
(827,10,'2026-10-09','2026-09-19 14:56:18'),
(893,14,'2026-09-21','2026-09-19 14:56:18'),
(894,14,'2026-09-22','2026-09-19 14:56:18'),
(895,14,'2026-09-23','2026-09-19 14:56:18'),
(896,14,'2026-09-24','2026-09-19 14:56:18'),
(897,14,'2026-09-25','2026-09-19 14:56:18'),
(900,14,'2026-09-28','2026-09-19 14:56:18'),
(901,14,'2026-09-29','2026-09-19 14:56:18'),
(902,14,'2026-09-30','2026-09-19 14:56:18'),
(903,14,'2026-10-01','2026-09-19 14:56:18'),
(904,14,'2026-10-02','2026-09-19 14:56:18'),
(907,14,'2026-10-05','2026-09-19 14:56:18'),
(908,14,'2026-10-06','2026-09-19 14:56:18'),
(909,14,'2026-10-07','2026-09-19 14:56:18'),
(910,14,'2026-10-08','2026-09-19 14:56:18'),
(911,14,'2026-10-09','2026-09-19 14:56:18');

/*Table structure for table `stalls` */

DROP TABLE IF EXISTS `stalls`;

CREATE TABLE `stalls` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `owner_id` bigint unsigned NOT NULL,
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  `location` varchar(180) COLLATE utf8mb4_unicode_ci NOT NULL,
  `daily_rent_price` int NOT NULL DEFAULT '0',
  `active` tinyint(1) NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `capacity` int NOT NULL DEFAULT '10',
  `harian_enabled` tinyint(1) NOT NULL DEFAULT '0',
  `scheme` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'kilogebrus',
  PRIMARY KEY (`id`),
  KEY `fk_stalls_owner` (`owner_id`),
  CONSTRAINT `fk_stalls_owner` FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=22 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `stalls` */

insert  into `stalls`(`id`,`owner_id`,`name`,`description`,`location`,`daily_rent_price`,`active`,`created_at`,`updated_at`,`capacity`,`harian_enabled`,`scheme`) values 
(1,6,'Lapak Cirata Utara','Spot tepi danau, parkir luas, toilet bersih','Danau Cirata, Purwakarta, Jawa Barat',75000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(2,6,'Lapak Cirata Selatan','Dekat dermaga, cocok lomba berat','Danau Cirata, Purwakarta, Jawa Barat',85000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(3,7,'Jatiluhur Spot A','Waduk tenang, umpan pelet & cacing','Waduk Jatiluhur, Purwakarta, Jawa Barat',60000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(4,7,'Jatiluhur Spot B','Area keluarga, warung tersedia','Waduk Jatiluhur, Purwakarta, Jawa Barat',55000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(5,8,'Gajah Mungkur Timur','Spot favorit ikan mas & nila','Waduk Gajah Mungkur, Wonogiri, Jawa Tengah',50000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(6,9,'Saguling Riverside','Aliran tenang, malam boleh mancing','Waduk Saguling, Bandung Barat, Jawa Barat',70000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(7,10,'Cileunca Lake View','Pemandangan pegunungan, udara sejuk','Situ Cileunca, Bandung, Jawa Barat',65000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(8,11,'Muara Angke Coastal','Mancing laut & muara, sewa perahu','Muara Angke, Jakarta Utara',90000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(9,12,'Rawa Pening Classic','Spot klasik Semarang–Salatiga','Rawa Pening, Semarang, Jawa Tengah',45000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(10,13,'Kedung Ombo Basecamp','Area luas, cocok event team','Waduk Kedung Ombo, Sragen, Jawa Tengah',55000,1,'2026-09-19 13:17:45','2026-09-19 13:17:45',10,1,'kilogebrus'),
(11,17,'Cirata Harian Kilogebrus','Kolam buka tiap hari skema kilo gebrus — bayar sesuai total berat ikan. Kapasitas terbatas.','Danau Cirata, Purwakarta, Jawa Barat',0,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',20,1,'kilogebrus'),
(12,17,'Cirata Borongan Family','Paket borongan harian: 1 spot untuk max 4 orang, umpan & air mineral termasuk.','Danau Cirata, Purwakarta, Jawa Barat',250000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',8,1,'borongan'),
(13,18,'Kolam Galatama Bandung Timur','Harian kilogebrus + borongan. Spot pelet, parkir motor/mobil.','Cibiru, Bandung, Jawa Barat',35000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',16,1,'kilogebrus_borongan'),
(14,18,'Bandung Weekend Borongan','Khusus akhir pekan — borongan 6 jam, max 6 pemancing per slot.','Cileunyi, Bandung, Jawa Barat',400000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',6,1,'borongan'),
(15,19,'Rawa Pening Harian KG','Mancing bebas kilo gebrus di rawaan — timbangan di pos pelapak.','Rawa Pening, Semarang, Jawa Tengah',0,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',24,1,'kilogebrus'),
(16,19,'Semarang Borongan Siang','Borongan 08.00–15.00, spot teduh, warung ikan bakar.','Genuk, Semarang, Jawa Tengah',180000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',10,1,'borongan'),
(17,20,'Bekasi Pond Kilogebrus','Kolam bundar harian, skema kilo gebrus nila & mas. Tutup kalau hujan deras.','Tambun, Bekasi, Jawa Barat',25000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',12,1,'kilogebrus'),
(18,20,'Bekasi Spot Borongan Malam','Borongan malam 18.00–24.00, lampu LED, kopi gratis.','Cikarang, Bekasi, Jawa Barat',220000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',8,1,'borongan'),
(19,21,'Situ Gede Mix Harian','Kilogebrus & borongan — pilih skema saat check-in di loket.','Situ Gede, Tasikmalaya, Jawa Barat',40000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',15,1,'kilogebrus_borongan'),
(20,22,'Pluit Muara Harian KG','Mancing muara harian kilo gebrus, sewa joran tersedia.','Pluit, Jakarta Utara, DKI Jakarta',50000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',18,1,'kilogebrus'),
(21,22,'Pluit Borongan Group','Borongan grup max 8 orang, cocok komunitas kantor.','Pluit, Jakarta Utara, DKI Jakarta',550000,1,'2026-09-19 14:39:37','2026-09-19 14:39:37',5,1,'borongan');

/*Table structure for table `users` */

DROP TABLE IF EXISTS `users`;

CREATE TABLE `users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(190) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` datetime NOT NULL,
  `updated_at` datetime NOT NULL,
  `points` int NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `users` */

insert  into `users`(`id`,`name`,`email`,`password`,`role`,`created_at`,`updated_at`,`points`) values 
(1,'Super Admin','superadmin@indofish.test','$2a$10$L026a9haU3TzD5/juHALM.y7iLXq8NPLWCtjFEYeZwX4UIkLtUMZe','superadmin','2026-09-19 09:25:59','2026-09-19 09:25:59',0),
(2,'Admin','admin@example.com','$2a$10$L026a9haU3TzD5/juHALM.y7iLXq8NPLWCtjFEYeZwX4UIkLtUMZe','admin','2026-09-19 09:25:59','2026-09-19 09:25:59',0),
(3,'User Biasa','user@example.com','$2a$10$L026a9haU3TzD5/juHALM.y7iLXq8NPLWCtjFEYeZwX4UIkLtUMZe','user','2026-09-19 09:25:59','2026-09-19 13:22:38',15),
(4,'Budi Lapak','owner@example.com','$2a$10$L026a9haU3TzD5/juHALM.y7iLXq8NPLWCtjFEYeZwX4UIkLtUMZe','owner','2026-09-19 09:25:59','2026-09-19 09:25:59',0),
(5,'Operator Event','operator@example.com','$2a$10$L026a9haU3TzD5/juHALM.y7iLXq8NPLWCtjFEYeZwX4UIkLtUMZe','operator','2026-09-19 09:25:59','2026-09-19 09:25:59',0),
(6,'Pak Hendra Cirata','pelapak.cirata@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','owner','2026-09-19 13:17:45','2026-09-19 13:17:45',55),
(7,'Bu Sari Jatiluhur','pelapak.jatiluhur@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','owner','2026-09-19 13:17:45','2026-09-19 13:17:45',55),
(8,'Om Rudi Gajah Mungkur','pelapak.gajahmungkur@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','owner','2026-09-19 13:17:45','2026-09-19 13:17:45',55),
(9,'Mas Dedi Saguling','pelapak.saguling@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','owner','2026-09-19 13:17:45','2026-09-19 13:17:45',55),
(10,'Kang Asep Situ Cileunca','pelapak.cileunca@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','owner','2026-09-19 13:17:45','2026-09-19 13:17:45',55),
(11,'Bang Rio Muara Angke','pelapak.muaraangke@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','owner','2026-09-19 13:17:45','2026-09-19 13:17:45',55),
(12,'Pak Yoga Rawa Pening','pelapak.rawapening@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','owner','2026-09-19 13:17:45','2026-09-19 13:17:45',55),
(13,'Mas Fajar Kedung Ombo','pelapak.kedungombo@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','owner','2026-09-19 13:17:45','2026-09-19 13:17:45',55),
(14,'Andi Pemancing','andi.mancing@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','user','2026-09-19 13:17:45','2026-09-19 13:17:45',25),
(15,'Rina Strike','rina.strike@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','user','2026-09-19 13:17:45','2026-09-19 13:17:45',25),
(16,'Tono Galatama','tono.galatama@indofish.test','$2a$10$iEsjq4GZ.Yjbl2kdsUPTuuH/Vi6M0sp17PyLpo1d9yR50cu5h27XC','user','2026-09-19 13:17:45','2026-09-19 13:17:45',25),
(17,'Bang Irwan Harian Cirata','harian.cirata@indofish.test','$2a$10$k17T3BjFJCrwMUdKw4rCJOSlA92p/yRgPRuzkMJqQ/o6zC4kHUUA6','owner','2026-09-19 14:39:37','2026-09-19 14:39:37',40),
(18,'Kang Ujang Kolam Bandung','harian.bandung@indofish.test','$2a$10$k17T3BjFJCrwMUdKw4rCJOSlA92p/yRgPRuzkMJqQ/o6zC4kHUUA6','owner','2026-09-19 14:39:37','2026-09-19 14:39:37',40),
(19,'Mas Yoga Harian Semarang','harian.semarang@indofish.test','$2a$10$k17T3BjFJCrwMUdKw4rCJOSlA92p/yRgPRuzkMJqQ/o6zC4kHUUA6','owner','2026-09-19 14:39:37','2026-09-19 14:39:37',40),
(20,'Pak Dodi Kolam Bekasi','harian.bekasi@indofish.test','$2a$10$k17T3BjFJCrwMUdKw4rCJOSlA92p/yRgPRuzkMJqQ/o6zC4kHUUA6','owner','2026-09-19 14:39:37','2026-09-19 14:39:37',40),
(21,'Bu Lina Situ Gede','harian.situgede@indofish.test','$2a$10$k17T3BjFJCrwMUdKw4rCJOSlA92p/yRgPRuzkMJqQ/o6zC4kHUUA6','owner','2026-09-19 14:39:37','2026-09-19 14:39:37',40),
(22,'Om Eko Waduk Pluit','harian.pluit@indofish.test','$2a$10$k17T3BjFJCrwMUdKw4rCJOSlA92p/yRgPRuzkMJqQ/o6zC4kHUUA6','owner','2026-09-19 14:39:37','2026-09-19 14:39:37',40);

/*Table structure for table `weights` */

DROP TABLE IF EXISTS `weights`;

CREATE TABLE `weights` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `event_id` bigint unsigned NOT NULL,
  `user_id` bigint unsigned NOT NULL,
  `weight` decimal(8,2) NOT NULL,
  `created_at` datetime NOT NULL,
  PRIMARY KEY (`id`),
  KEY `fk_weights_event` (`event_id`),
  KEY `fk_weights_user` (`user_id`),
  CONSTRAINT `fk_weights_event` FOREIGN KEY (`event_id`) REFERENCES `events` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_weights_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Data for the table `weights` */

insert  into `weights`(`id`,`event_id`,`user_id`,`weight`,`created_at`) values 
(1,2,3,2.35,'2026-09-19 09:25:59');

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;
