/// 여행 DNA 5유형 정적 데이터 — 프로토타입(DNA 상수)에서 그대로 옮김.
library;

import 'package:flutter/material.dart';

import '../models/dna_type.dart';

const Map<String, DnaType> kDnaTypes = {
  'nature': DnaType(
    id: 'nature',
    name: '자연탐험형 여행자',
    icon: '🌿',
    desc: '대자연 속에서 에너지를 얻고 조용한 힐링을 즐기는 탐험가예요.',
    recommendation: '자연 탐험',
    gradient: [Color(0xFF2F7D52), Color(0xFF1F5E3C)],
    tags: ['자연친화', '힐링', '사진', '트레킹'],
  ),
  'food': DnaType(
    id: 'food',
    name: '로컬 미식가',
    icon: '🍜',
    desc: '지역의 맛으로 여행을 기억하는 타입이에요. 진짜 여행은 현지 맛집에서 시작되죠.',
    recommendation: '미식 탐방',
    gradient: [Color(0xFFD27A3E), Color(0xFFA8551F)],
    tags: ['미식', '시장', '카페', '로컬'],
  ),
  'history': DnaType(
    id: 'history',
    name: '이야기 수집가',
    icon: '🏛️',
    desc: '골목과 유적에 담긴 이야기를 모으는 타입이에요. 오래된 것에서 깊이를 발견하죠.',
    recommendation: '역사 문화',
    gradient: [Color(0xFF6A5BB0), Color(0xFF473A8A)],
    tags: ['역사', '문화', '사찰', '박물관'],
  ),
  'activity': DnaType(
    id: 'activity',
    name: '에너지 탐험가',
    icon: '🧗',
    desc: '몸으로 부딪치며 즐기는 타입이에요. 가만히 있는 여행은 답답하죠.',
    recommendation: '액티비티',
    gradient: [Color(0xFF4C7FC4), Color(0xFF2F5F9F)],
    tags: ['액티비티', '등산', '체험', '짜릿'],
  ),
  'healing': DnaType(
    id: 'healing',
    name: '느림의 여행자',
    icon: '☕',
    desc: '천천히 머무르며 충전하는 타입이에요. 여백이 있는 여행을 사랑하죠.',
    recommendation: '힐링',
    gradient: [Color(0xFF6FA84A), Color(0xFF4D7C30)],
    tags: ['힐링', '휴식', '카페', '산책'],
  ),
};

DnaType dnaTypeById(String id) => kDnaTypes[id] ?? kDnaTypes['nature']!;
